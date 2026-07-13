# Top-level Home Manager entrypoint.
#
# Keep this file small so the actual configuration lives in focused modules under
# ./modules/home.
{ ... }:
{
  imports = [ ./modules/home ];
}
