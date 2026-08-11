# Repairs ELF binaries whose PT_LOAD program headers are not sorted by
# ascending p_vaddr.
#
# The ELF gABI requires this ordering, and glibc's dynamic loader relies on it
# (`_dl_map_segments` derives the total mapping span from the first and last
# PT_LOAD entries). glibc <= 2.40 tolerated violations; 2.41+ does not, and
# mis-maps the tail of the final RW segment. The first relocation written into
# the unmapped .bss pages then faults inside ld.so, before main() runs.
#
# `bun build --compile` (<= 1.3.13) produces exactly this: it embeds the JS
# payload by rewriting PT_GNU_STACK in place into a PT_LOAD, and PT_GNU_STACK
# sits early in the program header table. See oven-sh/bun#29967 and the
# nixpkgs tracking issues NixOS/nixpkgs#523047 / #520383.
#
# The fix permutes only the PT_LOAD entries among their existing slots in the
# program header table. Nothing moves in the file, no vaddrs change, no
# segment is added or removed, and non-PT_LOAD entries stay put. It is
# idempotent and a no-op on correctly ordered binaries.
{ ... }:
final: prev:

let
  # Use prev.lib, never final.lib: this overlay is evaluated while `final` is
  # still being constructed, so touching final.lib here is infinite recursion.
  inherit (prev) lib;

  sortElfPhdrs = final.writers.writePython3Bin "sort-elf-phdrs" { } ''
    """Sort PT_LOAD program headers by p_vaddr, in place."""
    import os
    import struct
    import sys

    PT_LOAD = 1
    PN_XNUM = 0xFFFF


    def fix(path):
        with open(path, "rb") as fh:
            head = fh.read(64)
        if len(head) < 64 or head[:4] != b"\x7fELF":
            return False
        if head[4] != 2 or head[5] != 1:  # ELFCLASS64, ELFDATA2LSB only
            return False

        (phoff,) = struct.unpack_from("<Q", head, 0x20)
        entsize, num = struct.unpack_from("<HH", head, 0x36)
        if phoff == 0 or num in (0, PN_XNUM) or entsize < 56:
            return False

        with open(path, "rb") as fh:
            fh.seek(phoff)
            raw = fh.read(entsize * num)
        if len(raw) != entsize * num:
            return False

        entries = [raw[i * entsize:(i + 1) * entsize] for i in range(num)]
        loads = [e for e in entries if struct.unpack_from("<I", e)[0] == PT_LOAD]
        vaddrs = [struct.unpack_from("<Q", e, 16)[0] for e in loads]
        if len(loads) < 2 or vaddrs == sorted(vaddrs):
            return False  # already conformant

        def vaddr_of(entry):
            return struct.unpack_from("<Q", entry, 16)[0]

        ordered = iter(sorted(loads, key=vaddr_of))
        rebuilt = [
            next(ordered) if struct.unpack_from("<I", e)[0] == PT_LOAD else e
            for e in entries
        ]

        mode = os.stat(path).st_mode
        os.chmod(path, mode | 0o200)
        try:
            with open(path, "r+b") as fh:
                fh.seek(phoff)
                fh.write(b"".join(rebuilt))
        finally:
            os.chmod(path, mode)
        return True


    def main():
        changed = 0
        for root in sys.argv[1:]:
            if os.path.isfile(root):
                targets = [root]
            else:
                targets = [
                    os.path.join(d, f)
                    for d, _, files in os.walk(root)
                    for f in files
                ]
            for path in targets:
                if os.path.islink(path):
                    continue
                try:
                    if fix(path):
                        print(f"sort-elf-phdrs: reordered PT_LOAD in {path}")
                        changed += 1
                except OSError as exc:
                    msg = "sort-elf-phdrs: skipping %s: %s" % (path, exc)
                    print(msg, file=sys.stderr)
        print("sort-elf-phdrs: repaired %d binaries" % changed)


    main()
  '';

  # Attach the repair to a derivation.
  #
  # Hooked via `preFixupPhases`, which stdenv expands unconditionally in its
  # phase list:
  #
  #   ... installPhase ${preFixupPhases:-} fixupPhase installCheckPhase ...
  #
  # That placement matters on both sides:
  #   - postInstall/postFixup are both unreliable here. postInstall only fires
  #     if the package's installPhase actually calls `runHook postInstall`,
  #     and postFixup never runs at all when `dontFixup = true` -- which is
  #     exactly what bun-based packages set, to stop strip/patchelf from
  #     corrupting the embedded runtime.
  #   - it runs *before* installCheckPhase, so a package whose installCheck
  #     executes its own binary (nixpkgs' hunk runs `$out/bin/hunk --version`)
  #     tests the repaired binary rather than the broken one.
  fixElfPhdrOrder =
    drv:
    drv.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ sortElfPhdrs ];
      preFixupPhases = (old.preFixupPhases or [ ]) ++ [ "sortElfPhdrsPhase" ];
      sortElfPhdrsPhase = ''
        for o in $(getAllOutputNames); do
          sort-elf-phdrs "''${!o}"
        done
      '';
    });

  # Packages known to ship binaries produced by `bun build --compile`.
  # Extend this list as you hit more of them.
  affected = [
    "hunk"
    "opencode"
  ];
in
{
  # Exposed as top-level attributes rather than folded into `lib`, which
  # would reintroduce the recursion described above.
  inherit sortElfPhdrs fixElfPhdrOrder;
}
// lib.genAttrs (lib.filter (n: prev ? ${n}) affected) (n: fixElfPhdrOrder prev.${n})
