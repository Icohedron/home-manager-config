# General-purpose packages that do not need extra program-level configuration.
{
  pkgs,
  useWayland,
  ...
}:
{
  home.packages = with pkgs; [
    # --- File & Disk Utilities ---
    dust
    dua
    file
    tree
    which
    (if useWayland then wl-clipboard else xsel)

    # --- Archives & Compression ---
    zip
    unzip
    p7zip

    # --- Task Runners & Process Management ---
    mask
    mprocs
    steam-run
    hyperfine

    # --- Development & Debugging ---
    valgrind-light
    lldb
    jq
    glow
    worktrunk
    dotenv-cli

    # --- Presentations & Misc ---
    presenterm
    doitlive
  ];
}
