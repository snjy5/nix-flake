{
  config,
  pkgs,
  lib,
  globals,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.${globals.username} = import ./home.nix;
  };
}
