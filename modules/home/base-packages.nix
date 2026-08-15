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
    steam-run
    hyperfine
    bubblewrap
    socat

    # --- Development & Debugging ---
    valgrind-light
    lldb
    jq
    glow
    worktrunk
    dotenv-cli
    hunk

    # --- Presentations & Misc ---
    presenterm
    doitlive
    drawio
  ];
}
