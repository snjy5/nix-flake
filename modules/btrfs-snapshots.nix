{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.services.btrfs-snapshots;

  # Define the script as a proper derivation in the 'let' block
  snapScript = pkgs.writeShellScript "btrfs-snapshots.sh" ''
    set -euo pipefail
    date="$(date '+%d-%m-%Y')"
    mkdir -p /snapshots
    rootfs="/snapshots/$date"

    # Remove existing snapshot for same date if present
    if [ -d "$rootfs" ]; then
      ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "$rootfs" || true
    fi

    # Create readonly snapshot of root
    ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot -r / "$rootfs"
  '';

in
{
  options.services.btrfs-snapshots = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable automatic btrfs snapshots via systemd timer.";
    };

    interval = mkOption {
      type = types.str;
      default = "6h";
      description = "Interval for snapshots (string for systemd OnUnitActiveSec).";
    };

    onBootSec = mkOption {
      type = types.str;
      default = "15m";
      description = "Delay after boot for first run (string for systemd OnBootSec).";
    };
  };

  config = mkIf cfg.enable {

    # If you still want the script visible in /etc for debugging:
    environment.etc."btrfs-snapshots.sh".source = snapScript;

    systemd.services."btrfs-snapshots" = {
      description = "Create readonly btrfs snapshot of /";
      # REMOVED: wantedBy = [ "multi-user.target" ];
      # Timers handle starting the service, it shouldn't start on boot directly.

      serviceConfig = {
        Type = "oneshot";
        # Point directly to the nix store derivation
        ExecStart = "${snapScript}";
      };
    };

    systemd.timers."btrfs-snapshots" = {
      description = "Run btrfs-snapshots on a timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = cfg.onBootSec;
        OnUnitActiveSec = cfg.interval;
        Persistent = true; # boolean, not string "true"
      };
    };
  };
}
