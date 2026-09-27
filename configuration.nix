# ./configuration.nix
# MacBookPro11,1: 13-inch Retina MacBook Pro 2013 or 2014 with Intel Haswell: Intel(R) Core(TM) i5-4258U CPU @ 2.40GHz
# not a Broadwell 2015 model.
# wifi: Broadcom BCM4360 802.11ac
# graphics: Intel Iris 5100 Graphics

{
  config,
  pkgs,
  lib,
  ...
}:

let
  # ===========================================================================
  # GLOBAL VARIABLES
  # ===========================================================================
  globals = {
    username = "void";
    initialPassword = "1234";
    hostname = "nixos";
    timeZone = "Asia/Kolkata";
    keyMap = "us";
    stateVersion = "26.05";

    # Disk & Encryption
    luksUuid = "f919548e-79a7-4209-b51f-3e67689883ca";

    # Devices
    androidPhone = {
      # Motorola PCS XT1541 [Moto G 3rd Gen]
      idVendor = "22b8";
      idProduct = "2e82";
    };
  };
in
{
  # Make globals accessible to all imported modules
  _module.args = { inherit globals; };

  imports = [
    ./hardware-configuration.nix
    ./modules/btrfs-snapshots.nix

    ./modules/nix-settings.nix
    ./modules/home-manager.nix
    ./modules/boot-hardware.nix
    ./modules/filesystems.nix
    ./modules/systemd-oom.nix
    ./modules/services.nix
    ./modules/network-security.nix
    ./modules/programs-shell.nix
    ./modules/environment-packages.nix
    ./modules/users.nix
  ];

  system.stateVersion = globals.stateVersion;
}
