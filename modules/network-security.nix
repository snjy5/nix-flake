{
  config,
  pkgs,
  lib,
  globals,
  ...
}:

{
  networking = {
    hostName = globals.hostname;
    networkmanager.enable = true;
    firewall = {
      enable = true;
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
    };
  };

  time.timeZone = globals.timeZone;
  console.keyMap = globals.keyMap;

  security = {
    rtkit.enable = true;
    pki.certificates = [ ];
    pam.services.swaylock = { };
    polkit.enable = true;
  };

  # Handles screencasting/screenshots for wlroots/sway for FileChooser, AppChooser, etc. 
  # For sway or plain window manager setups
  xdg.portal = {
    enable = true;
    wlr.enable = true; 
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk 
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      sway = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Screencast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
    };
  };

}
