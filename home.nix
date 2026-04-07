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
    (if useWayland then wl-clipboard else xsel) # Clipboard

    # --- Archives & Compression ---
    zip # File compression and archiving
    unzip # zip decompression
    p7zip # 7zip

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
    nixfmt # Nix code formatter
    jq # JSON processor

    # --- Presentations & Misc ---
    presenterm # Presentations written in Markdown, rendered in-terminal
    doitlive # Tool for live presentations in the terminal

    # --- AI / Helix Integration ---
    # Pipes selected text through opencode for AI-powered code transformations.
    # Usage in Helix: select text, press |, type: ai-replace "your prompt"
    (writeShellScriptBin "ai-replace" ''
      set -euo pipefail

      PROMPT="''${1:-Improve this code}"
      INPUT=$(cat)

      if [ -z "$INPUT" ]; then
        exit 0
      fi

      INSTRUCTIONS="You are a pure code transformation function."
      INSTRUCTIONS="$INSTRUCTIONS Your ONLY output must be the transformed code itself."
      INSTRUCTIONS="$INSTRUCTIONS RULES:"
      INSTRUCTIONS="$INSTRUCTIONS Output NOTHING except the final code."
      INSTRUCTIONS="$INSTRUCTIONS No markdown fences."
      INSTRUCTIONS="$INSTRUCTIONS No explanations, comments about changes, or preamble."
      INSTRUCTIONS="$INSTRUCTIONS No conversational text."
      INSTRUCTIONS="$INSTRUCTIONS No trailing newline."
      INSTRUCTIONS="$INSTRUCTIONS If you cannot transform the code, return it unchanged."
      INSTRUCTIONS="$INSTRUCTIONS Preserve the original indentation style."

      RESULT=$(printf '%s' "$INPUT" | opencode run --format json \
        "$INSTRUCTIONS $PROMPT:")

      # Extract text parts from JSON, strip markdown fences if they slipped through
      printf '%s' "$RESULT" | jq -r -s '
        [ .[] | select(.type == "text") | .part.text ] | join("")
      ' | sed -E '
        /^```[a-zA-Z]*$/d
        /^```$/d
      '
    '')
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
  programs.starship.enable = true;

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
          "space space g" = "git_panel::Toggle";
          "space space d" = "debug_panel::Toggle";
          "space space c" = "collab_panel::Toggle";
          "space space o" = "outline_panel::Toggle";
          "space space p" = "project_panel::Toggle";
          "space space n" = "notification_panel::Toggle";
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

      keys.normal.space.a = {
        i = ":pipe ai-replace 'Improve this code'";
        d = ":pipe ai-replace 'Add documentation comments to this code'";
        r = ":pipe ai-replace 'Refactor this code'";
        e = ":pipe ai-replace 'Explain this code by adding inline comments'";
        t = ":pipe ai-replace 'Write tests for this code'";
        f = ":pipe ai-replace 'Fix any bugs in this code'";
      };

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
  # SSH & Services
  # -------------------------------------------------------------------------
  programs.keychain = {
    enable = true;
    enableBashIntegration = true;
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
