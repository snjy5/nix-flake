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
      max-jobs = 128;

      # For downloads
      max-substitution-jobs = 128;
      http-connections = 50;
      http2 = true;
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
