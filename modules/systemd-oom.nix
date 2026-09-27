{
  config,
  pkgs,
  lib,
  ...
}:

{
  systemd.user.extraConfig = ''
    DefaultMemoryAccounting=yes
  '';

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableSystemSlice = true;
  };

  systemd.slices."user-".sliceConfig = {
    ManagedOOMMemoryPressure = "auto";
    ManagedOOMSwap = "auto";
    MemorySwapMax = "infinity";
    MemoryLow = "512M";
  };

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Prevent nixos-rebuild switch from restarting/stopping SDDM live
  systemd.services.display-manager.stopIfChanged = false;
  systemd.services.display-manager.restartIfChanged = false;
}
