{
  config,
  lib,
  pkgs,
  inputs,
  outputs,
  username,
  homeDirectory,
  gitUsername,
  gitEmail,
  useWayland,
  ...
}:
{
  # -------------------------------------------------------------------------
  # Nix & Nixpkgs Configuration
  # -------------------------------------------------------------------------
  nixpkgs.overlays = [ outputs.overlays.stable-packages ]; # Overlay stable pkgs to pkgs.stable
  nixpkgs.config.permittedInsecurePackages = [ ];
  nixpkgs.config.allowUnfree = true;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # For Non-NixOS systems, set this to true.
  targets.genericLinux.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should NOT change this value, even if you update Home Manager or Nixpkgs.
  # Changing this value DOES NOT upgrade your packages. It only changes the default
  # configuration values of certain programs to match new releases. It is meant to
  # track the state version of your original installation so that existing data and
  # databases don't break. Only change it if you explicitly understand the release
  # notes for the specific version.
  home.stateVersion = "25.11";

  # -------------------------------------------------------------------------
  # User Specifications
  # -------------------------------------------------------------------------
  home.username = username;
  home.homeDirectory = homeDirectory;

  # -------------------------------------------------------------------------
  # Packages & Session Variables
  # -------------------------------------------------------------------------
  home.packages = with pkgs; [
    # --- File & Disk Utilities ---
    dust # A better du (disk-use analyzer)
    dua # Interactive disk-use analyzer
    file # Show file type
    tree # Display directory trees
    which # Which?
    (if useWayland then wl-clipboard else xsel) # Clipboard

    # --- Archives & Compression ---
    zip # File compression and archiving
    unzip # zip decompression
    p7zip # 7zip

    # --- Sandboxing ---
    bubblewrap # Unprivileged sandboxing tool

    # --- Task Runners & Process Management ---
    mask # Markdown documentation that's also command runner like Make
    mprocs # Run multiple commands show the output of each
    steam-run # Run binaries in a FHS env
    hyperfine # Benchmark timing tool

    # --- Development & Debugging ---
    valgrind-light # Debugging and profiling
    lldb # Debugging
    nil # An LSP for Nix
    opencode # Coding agent
    graphify # Knowledge graph generator for AI
    smartcat # Pipe text to LLMs from the command line
    nixfmt # Nix code formatter
    jq # JSON processor
    glow # Markdown renderer for the CLI
    worktrunk # git worktrees

    # --- Helper Scripts ---
    (pkgs.writeShellScriptBin "pi-sandbox" ''
      # Launch pi inside a tightly sandboxed bubblewrap container.
      # Usage: pi-sandbox [paths...] [-- pi-args...]
      # The current directory is always the working directory.
      # Additional paths are bind-mounted read-write.
      # Arguments after -- are forwarded to pi.
      # GPU device nodes and the host X11/Wayland display are bound in when
      # present, so GUI applications can render with hardware acceleration.
      BIND_ARGS=()
      PI_ARGS=()
      PASSTHROUGH=0

      mkdir -p "$HOME/.pi"

      for arg in "$@"; do
        if [ "$PASSTHROUGH" -eq 1 ]; then
          PI_ARGS+=("$arg")
        elif [ "$arg" = "--" ]; then
          PASSTHROUGH=1
        else
          resolved=$(realpath "$arg")
          BIND_ARGS+=(--bind "$resolved" "$resolved")
        fi
      done

      WORK_DIR="$(realpath "$(pwd)")"

      # Build a minimal PATH: nix profile, pi npm binaries, and system essentials
      SANDBOX_PATH="$HOME/.pi/agent/bin:$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin"

      # Evaluate direnv for the target directory and inject the resulting
      # environment into the sandbox.  `direnv exec` always starts from a
      # clean baseline, so it works regardless of whether the parent shell
      # already loaded the .envrc.
      DIRENV_ARGS=()
      direnv_json=$(direnv exec "$WORK_DIR" env -0 2>/dev/null | tr '\0' '\n' || true)
      if [ -n "$direnv_json" ]; then
        while IFS='=' read -r key value; do
          [ -z "$key" ] && continue
          if [ "$key" = "PATH" ]; then
            SANDBOX_PATH="$value:$SANDBOX_PATH"
          else
            DIRENV_ARGS+=(--setenv "$key" "$value")
          fi
        done <<< "$direnv_json"
      fi

      # ---------------------------------------------------------------------
      # GPU + GUI display passthrough
      #
      # Bind the GPU device nodes and the host display sockets so GUI
      # applications (e.g. DX12/Vulkan apps under Proton) can render with
      # hardware acceleration.  Every bind is guarded so it is silently
      # skipped when the device/socket is absent (e.g. NVIDIA nodes on an AMD
      # box, or no Wayland socket on an X11-only session).
      # ---------------------------------------------------------------------
      GUI_ARGS=()

      # GPU device nodes: the DRI card/render nodes (Intel/AMD/Nouveau and the
      # NVIDIA render node) plus the NVIDIA proprietary driver nodes.
      for gpu_dev in /dev/dri \
                     /dev/nvidia0 /dev/nvidia1 /dev/nvidiactl \
                     /dev/nvidia-modeset /dev/nvidia-uvm /dev/nvidia-uvm-tools; do
        [ -e "$gpu_dev" ] && GUI_ARGS+=(--dev-bind "$gpu_dev" "$gpu_dev")
      done

      # NixOS userspace GPU drivers (no-op on generic Linux hosts, where the
      # drivers live under the already-bound /usr and /lib).
      [ -d /run/opengl-driver ] && GUI_ARGS+=(--ro-bind /run/opengl-driver /run/opengl-driver)
      [ -d /run/opengl-driver-32 ] && GUI_ARGS+=(--ro-bind /run/opengl-driver-32 /run/opengl-driver-32)

      # Vulkan ICD manifests that may live outside /usr.
      [ -d /etc/vulkan ] && GUI_ARGS+=(--ro-bind /etc/vulkan /etc/vulkan)

      # X11 display: bind the socket dir (over the /tmp tmpfs) and forward the
      # cookie so the client can authenticate.
      if [ -n "''${DISPLAY:-}" ] && [ -d /tmp/.X11-unix ]; then
        GUI_ARGS+=(--ro-bind /tmp/.X11-unix /tmp/.X11-unix --setenv DISPLAY "$DISPLAY")
        if [ -n "''${XAUTHORITY:-}" ] && [ -f "$XAUTHORITY" ]; then
          GUI_ARGS+=(--ro-bind "$XAUTHORITY" "$XAUTHORITY" --setenv XAUTHORITY "$XAUTHORITY")
        fi
      fi

      # Wayland display: bind just the compositor socket inside the runtime dir.
      if [ -n "''${WAYLAND_DISPLAY:-}" ] && [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
        wl_sock="$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
        if [ -e "$wl_sock" ]; then
          GUI_ARGS+=(--ro-bind "$wl_sock" "$wl_sock" \
            --setenv WAYLAND_DISPLAY "$WAYLAND_DISPLAY" \
            --setenv XDG_RUNTIME_DIR "$XDG_RUNTIME_DIR")
        fi
      fi

      exec bwrap \
        --new-session \
        --cap-drop ALL \
        --ro-bind /dev/null /usr/bin/distrobox-host-exec \
        --ro-bind /dev/null /usr/bin/distrobox-export \
        --ro-bind /dev/null /usr/bin/host-spawn \
        --ro-bind /nix /nix \
        --ro-bind /usr /usr \
        --symlink usr/bin /bin \
        --symlink usr/sbin /sbin \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --ro-bind /etc/hosts /etc/hosts \
        --ro-bind /etc/passwd /etc/passwd \
        --ro-bind /etc/group /etc/group \
        --ro-bind /etc/nsswitch.conf /etc/nsswitch.conf \
        --ro-bind-try /etc/ssl /etc/ssl \
        --ro-bind-try /etc/pki /etc/pki \
        --ro-bind /lib /lib \
        --ro-bind-try /lib64 /lib64 \
        --ro-bind-try /lib32 /lib32 \
        --tmpfs /run/host \
        --proc /proc \
        --dev /dev \
        --ro-bind-try /sys /sys \
        --tmpfs /dev/shm \
        --tmpfs /tmp \
        --unshare-pid \
        --unshare-uts \
        --unshare-ipc \
        --ro-bind "$HOME/.nix-profile/bin" "$HOME/.nix-profile/bin" \
        --bind "$HOME/.pi" "$HOME/.pi" \
        --bind "$WORK_DIR" "$WORK_DIR" \
        "''${BIND_ARGS[@]}" \
        --setenv HOME "$HOME" \
        "''${DIRENV_ARGS[@]}" \
        --setenv PATH "$SANDBOX_PATH" \
        --ro-bind "$HOME/.config/git/config" "$HOME/.config/git/config" \
        --setenv SANDBOX "1" \
        "''${GUI_ARGS[@]}" \
        --unsetenv DBUS_SESSION_BUS_ADDRESS \
        --chdir "$WORK_DIR" \
        --die-with-parent \
        -- pi "''${PI_ARGS[@]}"
    '')

    # --- Presentations & Misc ---
    presenterm # Presentations written in Markdown, rendered in-terminal
    doitlive # Tool for live presentations in the terminal
  ];

  home.sessionVariables = { };


  # -------------------------------------------------------------------------
  # Shell & Shell Integration
  # -------------------------------------------------------------------------
  home.shell.enableShellIntegration = true;
  home.shellAliases = {
    grep = "rg";
    cd = "z";
    cdi = "zi";
  };

  programs.bash.enable = true;
  programs.bash.initExtra = ''
    # Skip keychain inside sandbox — reuse the inherited SSH_AUTH_SOCK instead
    if [[ -z "$SANDBOX" ]]; then
      eval "$(SHELL=bash ${pkgs.keychain}/bin/keychain --eval --quiet id_ed25519)"
    fi

    # Worktrunk shell integration
    if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
  '';

  programs.nushell = {
    enable = true;
    settings = {
      show_banner = false;
      buffer_editor = "hx";
    };
    extraConfig =
      let
        completion_dir = "${pkgs.nu_scripts}/share/nu_scripts/custom-completions";
        completions = [
          "git"
          "zellij"
          "mask"
        ];
      in
      lib.concatMapStringsSep "\n" (
        cmplt: "source ${completion_dir}/${cmplt}/${cmplt}-completions.nu"
      ) completions
      + "\n\n# Worktrunk shell integration\n"
      + ''if (which wt | is-not-empty) { mkdir ($nu.default-config-dir | path join vendor/autoload); wt config shell init nu | save --force ($nu.default-config-dir | path join vendor/autoload/wt.nu) }'';
  };

  programs.carapace.enable = true;
  programs.starship = {
    enable = true;
    settings = {
      env_var.SANDBOX = {
        style = "bold red";
        variable = "SANDBOX";
        format = "[\\[sandbox\\] ]($style)";
      };
    };
  };

  # -------------------------------------------------------------------------
  # CLI Tools & Utilities
  # -------------------------------------------------------------------------
  programs.bat.enable = true; # A better cat
  programs.btop.enable = true; # Display running processes
  programs.eza.enable = true; # A better ls
  programs.fastfetch.enable = true; # Display system information
  programs.fd.enable = true; # A better find
  programs.fzf.enable = true; # A fuzzy finder
  programs.ripgrep.enable = true; # A better grep
  programs.ripgrep-all.enable = true; # ripgrep that works in container files

  programs.yazi = {
    enable = true; # A better ranger
    shellWrapperName = "y"; # Silence warning
  };

  programs.zellij = {
    enable = true; # A better tmux
  };

  xdg.configFile."zellij/config.kdl".text = ''
    show_startup_tips false
    mouse_mode true

    keybinds {
        shared_except "locked" {
            bind "Alt g" {
                Run "lazygit" {
                    floating true
                    x "10%"
                    y "10%"
                    width "80%"
                    height "80%"
                }
            }
        }
    }
  '';

  programs.direnv = {
    enable = true; # Auto-load/unload envs per directory
    nix-direnv.enable = true; # Faster nix integration, caches dev shells
  };

  programs.zoxide.enable = true; # A better cd

  programs.lazygit.enable = true; # A simple terminal UI for git commands
  programs.gh.enable = true; # GitHub CLI
  programs.gitui.enable = true; # Terminal UI for git
  programs.delta.enable = true; # A better diff and pager for git

  # -------------------------------------------------------------------------
  # Version Control System Configuration
  # -------------------------------------------------------------------------
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = gitUsername;
        email = gitEmail;
        signingkey = "~/.ssh/id_ed25519.pub";
      };
      # Helix as default editor
      core.editor = "hx";
      # Delta options
      delta.navigate = true;
      delta.dark = true;
      merge.conflictstyle = "zdiff3";
      # Sign all commits using an ssh key
      commit.gpgsign = true;
      gpg.format = "ssh";
    };
    signing.format = null;
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = gitUsername;
        email = gitEmail;
      };
      signing = {
        sign-all = true;
        backend = "ssh";
        key = "~/.ssh/id_ed25519.pub";
      };
      ui = {
        editor = "hx";
      };
    };
  };

  # -------------------------------------------------------------------------
  # Editors
  # -------------------------------------------------------------------------

  # --- Zed ---
  programs.zed-editor = {
    enable = true;
    userSettings = {
      edit_predictions = {
        provider = "copilot";
      };
      agent_servers = {
        opencode = {
          type = "registry";
        };
      };
      agent = {
        default_model = {
          provider = "copilot_chat";
          model = "claude-opus-4.8";
          enable_thinking = true;
          effort = "high";
        };
        favorite_models = [ ];
        model_parameters = [ ];
      };
      helix_mode = true;
      which_key = {
        enabled = true;
        delay_ms = 100;
      };
      base_keymap = "VSCode";
      theme = "Aura Dark";
      icon_theme = "Warm Charmed Icons";
      theme_overrides = {
        "Aura Dark" = {
          "border" = "#15141C";
          "border.variant" = "#15141C";
          "panel.background" = "#15141C";
          "tab_bar.background" = "#15141C";
          "terminal.background" = "#15141C";
          "tab.inactive_background" = "#15141C";
          "title_bar.inactive_background" = "#110f18";
          "panel.focused_border" = "#4E466E";
        };
      };
      title_bar = {
        show_user_menu = false;
        show_user_picture = false;
        show_sign_in = false;
      };
      tab_bar = {
        show = true;
      };
      current_line_highlight = "none";
      lsp = {
        # Use clangd from clang-tools to get a clangd that can find std headers
        "clangd" = {
          binary = {
            path = "${pkgs.llvmPackages_latest.clang-tools.override { enableLibcxx = false; }}/bin/clangd";
          };
        };
      };
    };
    extensions = [
      "aura-theme"
      "charmed-icons"
      "nix"
    ];
    userKeymaps = [
      {
        context = "(VimControl && !menu)";
        bindings = {
          "space" = null;
          "space space c" = "collab_panel::Toggle";
          "space G" = "debug_panel::Toggle";
          "space e" = "project_panel::Toggle";
          "space space g" = "git_panel::Toggle";
          "space space o" = "outline_panel::Toggle";
          "] g" = "editor::GoToHunk";
          "[ g" = "editor::GoToPreviousHunk";
          "] G" = "editor::GoToPreviousDiagnostic";
          "[ G" = "editor::GoToHunk";
          "] d" = "editor::GoToDiagnostic";
          "[ d" = "editor::GoToPreviousDiagnostic";
          "] D" = "editor::GoToPreviousDiagnostic";
          "[ D" = "editor::GoToDiagnostic";
          "=" = "editor::FormatSelections";
        };
      }
      {
        "context" = "(vim_mode == helix_normal || vim_mode == helix_select) && !menu";
        "bindings" = {
          "space b" = "tab_switcher::Toggle";
        };
      }
    ];
  };

  # --- Helix ---
  programs.helix = {
    enable = true;
    defaultEditor = true;
    settings = {
      theme = "catppuccin_mocha";

      editor = {
        auto-save = true;
        bufferline = "always";
        cursorcolumn = true;
        cursorline = true;
        mouse = true;
        rulers = [ 80 ];
        text-width = 80;
        true-color = true;

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        file-picker = {
          hidden = false;
        };

        soft-wrap = {
          enable = true;
          wrap-at-text-width = false;
          wrap-indicator = "↩ ";
        };

        statusline = {
          center = [ "file-name" ];
          left = [
            "mode"
            "spinner"
          ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
            "file-line-ending"
            "file-type"
          ];
          separator = "|";

          mode = {
            insert = "INSERT";
            normal = "NORMAL";
            select = "SELECT";
          };
        };

        whitespace.characters = {
          nbsp = "⍽";
          newline = "⏎";
          nnbsp = "␣";
          space = "·";
          tab = "→";
          tabpad = "·";
        };

        whitespace.render = {
          nbsp = "none";
          newline = "all";
          nnbsp = "none";
          space = "none";
          tab = "all";
        };

        indent-guides = {
          render = true;
        };

        inline-diagnostics = {
          cursor-line = "hint";
        };
      };
    };

    languages = {
      language-server.clangd = {
        # Use clangd from clang-tools to get a clangd that can find std headers
        command = "${pkgs.llvmPackages_latest.clang-tools.override { enableLibcxx = false; }}/bin/clangd";
      };

      language = [
        {
          name = "nix";
          scope = "source.nix";
          injection-regex = "nix";
          file-types = [ "nix" ];
          shebangs = [ ];
          comment-token = "#";
          language-servers = [
            "nil"
            "nixd"
          ];
          indent = {
            tab-width = 2;
            unit = "  ";
          };
          formatter = {
            command = "nixfmt";
          };
        }
        {
          name = "hlsl";
          scope = "source.hlsl";
          injection-regex = "hlsl";
          file-types = [
            "hlsl"
            "fx"
            "cginc"
            "compute"
          ];
          comment-token = "//";
          grammar = "c";
          language-servers = [ ];
          indent = {
            tab-width = 4;
            unit = "    ";
          };
        }
      ];
    };
  };

  xdg.configFile."helix/runtime/queries/hlsl/highlights.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/injections.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/locals.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/textobjects.scm".text = "; inherits: c";
  xdg.configFile."helix/runtime/queries/hlsl/indents.scm".text = "; inherits: c";

  # -------------------------------------------------------------------------
  # Pi Coding Agent
  # -------------------------------------------------------------------------

  programs.pi-coding-agent = {
    enable = true;
    extraPackages = with pkgs; [
      nodejs
      bun
    ];
    settings = {
      defaultProvider = "github-copilot";
      defaultModel = "claude-opus-4.8";
      defaultThinkingLevel = "high";
      packages = [
        "npm:pi-btw"
        "npm:pi-minions"
        "npm:pi-permission-system"
        "npm:@ifi/oh-pi-prompts"
        "npm:@tmustier/pi-files-widget"
      ];
    };
  };

  # pi-permission-system config & policy — copied (not symlinked) so the
  # extension can still write to the files.  Reset on every switch.
  home.activation.piPermissions =
    let
      extensionConfig = builtins.toJSON {
        debugLog = false;
        permissionReviewLog = true;
        yoloMode = false;
      };

      permissionsPolicy = builtins.toJSON {
        defaultPolicy = {
          tools = "allow";
          bash = "allow";
          mcp = "allow";
          skills = "allow";
          special = "allow";
        };
        bash = {
          # ── HTTP clients ──────────────────────────────────────
          "*curl *" = "ask";
          "*wget *" = "ask";

          # ── Remote shells & file transfer ─────────────────────
          "*ssh *" = "ask";
          "*scp *" = "ask";
          "*sftp *" = "ask";
          "*rsync *" = "ask";
          "*ftp *" = "ask";

          # ── Raw sockets / tunnels ─────────────────────────────
          "nc *" = "ask";
          "*netcat *" = "ask";
          "*ncat *" = "ask";
          "*socat *" = "ask";
          "*telnet *" = "ask";
          "*/dev/tcp/*" = "ask";
          "*/dev/udp/*" = "ask";

          # ── Git push (sends code to remotes) ──────────────────
          "git push*" = "ask";
          "git remote add*" = "ask";
          "git remote set-url*" = "ask";

          # ── Container / cloud pushes ──────────────────────────
          "*docker push*" = "ask";
          "*podman push*" = "ask";

          # ── Mail ──────────────────────────────────────────────
          "*sendmail *" = "ask";
          "*mailx *" = "ask";

          # ── Tunnel / expose services ──────────────────────────
          "*ngrok*" = "ask";

          # ── Inline interpreters opening network ────────────────
          "*python*http.server*" = "ask";
          "*python*SimpleHTTPServer*" = "ask";

          # ── System package managers ──
          "nix *" = "ask";
          "*nix-env *" = "ask";
          "*nix-build *" = "ask";
          "*nix-shell *" = "ask";
          "*nix-store *" = "ask";
          "*nixos-rebuild *" = "ask";
          "*home-manager *" = "ask";
        };
      };
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pi_dir="$HOME/.pi/agent"
      ext_dir="$HOME/.pi/agent/npm/node_modules/pi-permission-system"
      $DRY_RUN_CMD mkdir -p "$ext_dir"
      $DRY_RUN_CMD cp --remove-destination \
        ${pkgs.writeText "pi-permission-system-config.json" extensionConfig} \
        "$ext_dir/config.json"
      $DRY_RUN_CMD chmod 644 "$ext_dir/config.json"
      $DRY_RUN_CMD cp --remove-destination \
        ${pkgs.writeText "pi-permissions.jsonc" permissionsPolicy} \
        "$pi_dir/pi-permissions.jsonc"
      $DRY_RUN_CMD chmod 644 "$pi_dir/pi-permissions.jsonc"
    '';

  # Extensions — symlinked from the Nix store (read-only is fine).
  # home.file.".pi/agent/extensions/my-extension.ts".text = ''
  #   import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
  #
  #   export default function (pi: ExtensionAPI) {
  #     pi.on("session_start", async (_event, ctx) => {
  #       ctx.ui.notify("Extension loaded!", "info");
  #     });
  #   }
  # '';

  # -------------------------------------------------------------------------
  # SSH & Services
  # -------------------------------------------------------------------------
  programs.keychain = {
    enable = true;
    enableBashIntegration = false;
    enableNushellIntegration = true;
    keys = [ "id_ed25519" ];
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # Silence warning
    settings."*".addKeysToAgent = "yes";
  };
}
