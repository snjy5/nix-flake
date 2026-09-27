{
  config,
  pkgs,
  lib,
  globals,
  ...
}:

{
  programs = {
    sway = {
      enable = true;
      wrapperFeatures.gtk = true;
    };

    kdeconnect.enable = true;
    zsh.enable = true;
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTR{idVendor}=="${globals.androidPhone.idVendor}", MODE="[]", GROUP="adbusers", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTR{idVendor}=="${globals.androidPhone.idVendor}", ATTR{idProduct}=="${globals.androidPhone.idProduct}", SYMLINK+="android_adb"
    SUBSYSTEM=="usb", ATTR{idVendor}=="${globals.androidPhone.idVendor}", ATTR{idProduct}=="${globals.androidPhone.idProduct}", SYMLINK+="android_fastboot"
  '';
}
