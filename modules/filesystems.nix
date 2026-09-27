{
  config,
  pkgs,
  lib,
  ...
}:

{
  fileSystems = lib.mkForce {
    "/" = {
      device = "/dev/mapper/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@"
        "noatime"
        "discard=async"
        "space_cache=v2"
      ];
    };
    "/snapshots" = {
      device = "/dev/mapper/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots"
        "noatime"
        "discard=async"
        "space_cache=v2"
      ];
      depends = [ "/" ];
    };
    "/swap" = {
      device = "/dev/mapper/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
        "nodatacow"
      ];
      depends = [ "/" ];
    };
    "/boot" = {
      device = "LABEL=EFI";
      fsType = "vfat";
      options = [
        "umask=077"
        "shortname=winnt"
      ];
    };
  };

  system.activationScripts.btrfsSwapfile = {
    text = ''
      if [ ! -e /swap/swapfile ]; then
        echo "Creating Btrfs swapfile..."
        ${pkgs.btrfs-progs}/bin/btrfs filesystem mkswapfile --size 10G --uuid clear /swap/swapfile
      fi
    '';
    deps = [ "specialfs" ];
  };

  swapDevices = lib.mkForce [ { device = "/swap/swapfile"; } ];
}
