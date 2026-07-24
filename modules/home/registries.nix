# Default package registries for npm, PyPI, and NuGet, applied globally.
#
# The registry URLs are provided per-user from user.nix. This module writes the
# canonical global config files for each tool and also exports the matching
# environment variables so CLIs that prefer env config (npm, pip, uv) pick them
# up as well.
{
  lib,
  homeDirectory,
  npmRegistry,
  pypiRegistry,
  nugetRegistry,
  ...
}:
{
  # ---------------------------------------------------------------------------
  # Config files (the canonical, tool-agnostic global settings)
  # ---------------------------------------------------------------------------

  # npm / pnpm / yarn read ~/.npmrc
  home.file.".npmrc".text = ''
    registry=${npmRegistry}
  '';

  # pip reads ~/.config/pip/pip.conf
  home.file.".config/pip/pip.conf".text = ''
    [global]
    index-url = ${pypiRegistry}
  '';

  # NuGet reads ~/.nuget/NuGet/NuGet.Config
  home.file.".nuget/NuGet/NuGet.Config".text = ''
    <?xml version="1.0" encoding="utf-8"?>
    <configuration>
      <packageSources>
        <clear />
        <add key="default" value="${nugetRegistry}" />
      </packageSources>
    </configuration>
  '';

  # ---------------------------------------------------------------------------
  # Environment variables (belt-and-suspenders for env-driven CLIs)
  # ---------------------------------------------------------------------------
  home.sessionVariables = {
    NPM_CONFIG_REGISTRY = npmRegistry;
    PIP_INDEX_URL = pypiRegistry;
    UV_INDEX_URL = pypiRegistry;
  };
}
