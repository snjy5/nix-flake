{
  description = "My NixOS Flake";

  inputs = {
    # Pin Nixpkgs to 26.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Pin Home Manager to the EXACT SAME release (26.05)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";

      # This line forces Home Manager to use YOUR nixpkgs input
      # instead of downloading its own separate copy.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./configuration.nix
          home-manager.nixosModules.home-manager
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.certbot ];
      };
    };
}
