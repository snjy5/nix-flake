# ./flake.nix
{
  description = "My NixOS Flake";

  inputs = {
    # Pin Nixpkgs to 26.05
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Pin Home Manager to the EXACT SAME release (26.05)
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Fix: Added nixos-hardware here
  outputs =
    {
      nixpkgs,
      home-manager,
      nixos-hardware,
      ...
    }:
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
          nixos-hardware.nixosModules.apple-macbook-pro-11-1
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ pkgs.certbot ];
      };
    };
}
