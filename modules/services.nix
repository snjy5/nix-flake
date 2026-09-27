{
  config,
  pkgs,
  lib,
  ...
}:

{
  services = {
    dbus.enable = true;
    thermald.enable = true;
    upower.enable = true;
    fwupd.enable = true;
    fstrim.enable = true;
    libinput.enable = true;

    btrfs.autoScrub = {
      enable = true;
      fileSystems = [ "/" ];
    };

    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
        CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
        USB_AUTOSUSPEND = 0;
        USB_EXCLUDE_AUDIO = 1;
        USB_EXCLUDE_INPUT = 1;
        USB_EXCLUDE_WWAN = 1;
        USB_AUTOSUSPEND_DISABLE_ON_STARTUP = 1;
        WIFI_DISABLE_ON_LID_CLOSE = 0;
        BLUETOOTH_DISABLE_ON_LID_CLOSE = 0;
        START_CHARGE_THRESH_BAT0 = 75;
        STOP_CHARGE_THRESH_BAT0 = 80;
      };
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      jack.enable = true;
      wireplumber.enable = true;
    };

    btrfs-snapshots.enable = true;

    openssh = {
      enable = true;
      openFirewall = true;
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    nginx = {
      enable = true;
      virtualHosts."localhost" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 80;
          }
        ];
        locations."/" = {
          root = "/srv/http";
          index = "index.html";
        };
      };
    };

    mbpfan = {
      enable = true;
      settings = {
        general = {
          min_fan1_speed = 1300;
          max_fan1_speed = 6200;
          low_temp = 55;
          high_temp = 55;
          max_temp = 55;
          polling_interval = 2;
        };
      };
    };
  };

  virtualisation.docker.enable = true;

}
