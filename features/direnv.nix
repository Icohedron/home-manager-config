# direnv - per-directory environments, wired to nix-direnv.
{ config, ... }:
{
  flake.modules.homeManager.direnv =
    { lib, ... }:
    {
      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      # devenv's progress UI (`devenv direnv-export`, run by `use devenv`)
      # probes the terminal with escape queries (CSI ? u, CSI c) and reads the
      # replies from *stdin*, swallowing anything already typed ahead. That
      # eats keystrokes typed while entering a devenv directory, and it makes
      # herdr's `session.resume_agents_on_restore` fail: herdr types
      # `pi --session ...` into a freshly spawned pane shell, direnv runs from
      # the first precmd, and devenv consumes the line before zsh reads it.
      # Give the direnv hook (and therefore every .envrc child process) an
      # empty stdin so terminal input is never drained by an env reload.
      programs.zsh.initContent = lib.mkAfter ''
        if (( $+functions[_direnv_hook] )); then
          functions[_direnv_hook_with_inherited_stdin]=$functions[_direnv_hook]
          _direnv_hook() { _direnv_hook_with_inherited_stdin "$@" </dev/null; }
        fi
      '';

      # home-manager installs the bash hook with mkAfter (order 1500), so the
      # wrapper has to be ordered after that to see the function.
      programs.bash.initExtra = lib.mkOrder 1600 ''
        if declare -F _direnv_hook >/dev/null 2>&1; then
          eval "_direnv_hook_with_inherited_stdin() $(declare -f _direnv_hook | tail -n +2)"
          _direnv_hook() { _direnv_hook_with_inherited_stdin "$@" </dev/null; }
        fi
      '';
    };

  flake.modules.homeManager.workstation.imports = [ config.flake.modules.homeManager.direnv ];
}
