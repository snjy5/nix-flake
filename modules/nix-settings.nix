{
  config,
  pkgs,
  lib,
  ...
}:

{
  nix = {
    channel.enable = false;
    nixPath = [ ];
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      fallback = false;
      max-jobs = 16;
    };
    gc = {
      automatic = true;
      dates = "weekly";
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowInsecurePredicate = pkg: (pkg.pname or pkg.name) == "broadcom-sta";
  };
}
