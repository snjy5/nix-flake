{
  config,
  pkgs,
  lib,
  globals,
  ...
}:

{
  users.users = {
    root.initialPassword = globals.initialPassword;
    ${globals.username} = {
      isNormalUser = true;
      initialPassword = globals.initialPassword;
      shell = pkgs.zsh;
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "input"
        "docker"
        "adbusers"
      ];
    };
  };
}
