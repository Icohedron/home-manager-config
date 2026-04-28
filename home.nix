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
    opencode # Agentic coding assistant
    smartcat # Pipe text to LLMs from the command line
    nixfmt # Nix code formatter
    jq # JSON processor
    glow # Markdown renderer for the CLI
    pi-coding-agent # Agentic coding assistant
    nodejs # JavaScript
    bun # JavaScript runtime

    # --- Helper Scripts ---
    (pkgs.writeShellScriptBin "pi-sandbox" ''
      # Launch pi inside a tightly sandboxed bubblewrap container.
      # Usage: pi-sandbox [paths...] [-- pi-args...]
      # The current directory is always the working directory.
      # Additional paths are bind-mounted read-write.
      # Arguments after -- are forwarded to pi.
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
      SANDBOX_PATH="$HOME/.pi/agent/bin:$HOME/.nix-profile/bin:$HOME/.pi/npm/bin:/nix/var/nix/profiles/default/bin:/usr/bin"

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
        --unsetenv DISPLAY \
        --unsetenv WAYLAND_DISPLAY \
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

  # The npm packages for Pi can come with binaries that should be on the PATH.
  home.sessionPath = [ "$HOME/.pi/npm/bin" ];

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
      ) completions;
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
  # Smartcat Configuration
  # -------------------------------------------------------------------------
  
  xdg.configFile."smartcat/.api_configs.toml".text = ''
    [openai]
    api_key_command = "echo $OPENAI_TOKEN"
    url = "http://127.0.0.1:4141/v1/chat/completions"
    default_model = "claude-opus-4.6"
  '';

  xdg.configFile."smartcat/prompts.toml".text = ''
    [default]
    api = "openai"
    char_limit = 65536

    [[default.messages]]
    role = "system"
    content = """\
    You are an expert programmer and system administrator. You value code efficiency and clarity above all things. Your output will be piped directly into other CLI programs or files. Follow these rules strictly:\
    1. Output ONLY the direct result of the task. No preamble, no summary, no sign-off.\
    2. Never wrap output in code fences (```), markdown formatting, or any decorative markup unless the task explicitly requires generating markdown.\
    3. Never explain your reasoning or approach unless the user explicitly asks for an explanation.\
    4. Preserve the exact formatting, indentation style, and line endings of any input provided.\
    5. Do not add trailing newlines beyond what the content requires.\
    6. If the task is ambiguous, make the most reasonable interpretation and proceed rather than asking clarifying questions.\
    7. If given code to modify, return the complete modified result, not a partial diff, unless a diff is requested.\
    8. Treat piped stdin content as the primary data to operate on. Treat the user's prompt as the instruction for what to do with that data.\
    9. If no input is piped and the prompt is a task, produce the requested output directly.\
    10. Never refuse a task by restating your limitations. Attempt the task to the best of your ability.\
    """

    [empty]
    api = "openai"
    messages = []
  '';

  # -------------------------------------------------------------------------
  # Git Configuration
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
          model = "claude-opus-4.6";
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

  # Settings — copied (not symlinked) so pi can still write to the file.
  # Reset to this declarative baseline on every `home-manager switch`.
  home.activation.piSettings =
    let
      piPackages = [ # pi-pkgs
        "pi-btw@0.3.7"
        "@victor-software-house/pi-openai-proxy@4.9.3"
        "@ifi/oh-pi-prompts@0.4.4"
        "@tmustier/pi-files-widget@0.1.20"
      ];

      # npm wrapper — redirects global prefix to writable ~/.pi/npm
      # since Nix's nodejs has its prefix in the read-only store.
      npm-wrapper = pkgs.writeShellScriptBin "npm" ''
        export NPM_CONFIG_PREFIX="$HOME/.pi/npm"
        export PATH="${pkgs.nodejs}/bin:$PATH"
        exec ${pkgs.nodejs}/bin/npm "$@"
      '';

      settings = builtins.toJSON {
        defaultProvider = "github-copilot";
        defaultModel = "claude-opus-4.6";
        defaultThinkingLevel = "high";
        npmCommand = [ "${npm-wrapper}/bin/npm" ];
        packages = map (p: "npm:${p}") piPackages;
      };
    in
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      pi_dir="$HOME/.pi/agent"
      npm="${npm-wrapper}/bin/npm"
      $DRY_RUN_CMD mkdir -p "$pi_dir"
      $DRY_RUN_CMD cp --remove-destination \
        ${pkgs.writeText "pi-settings.json" settings} \
        "$pi_dir/settings.json"
      $DRY_RUN_CMD chmod 644 "$pi_dir/settings.json"

      # Install declared packages
      ${lib.concatMapStringsSep "\n      " (pkg:
        "$DRY_RUN_CMD $npm install -g ${pkg}"
      ) piPackages}

      # Uninstall packages not in the declared list
      declared=${pkgs.writeText "pi-declared-pkgs" (lib.concatMapStringsSep "\n" (pkg:
        # Strip version: "@scope/name@ver" -> "@scope/name", "name@ver" -> "name"
        let parts = builtins.match "(@[^@]+)@.*" pkg; in
        if parts != null then builtins.head parts
        else builtins.head (builtins.match "([^@]+)@.*" pkg)
      ) piPackages)}
      for installed in $($npm ls -g --depth=0 --parseable 2>/dev/null | tail -n+2); do
        name=$(basename "$installed")
        parent=$(basename "$(dirname "$installed")")
        if [[ "$parent" == @* ]]; then
          name="$parent/$name"
        fi
        if ! grep -qxF "$name" "$declared"; then
          echo "Removing undeclared pi package: $name"
          $DRY_RUN_CMD $npm uninstall -g "$name"
        fi
      done
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
    matchBlocks."*".addKeysToAgent = "yes";
  };

  # -------------------------------------------------------------------------
  # Browser
  # -------------------------------------------------------------------------
  programs.firefox.enable = true;
}
