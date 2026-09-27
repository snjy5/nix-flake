# ./modules/home.nix
{ pkgs, ... }:

{
  home.username = "void";
  home.homeDirectory = "/home/void";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  services.kdeconnect = {
    enable = true;
    indicator = true; # Set to true if you want the tray icon
  };

  # Any other user-level packages you want
  #home.packages = with pkgs; [
  # fastfetch
  # ripgrep
  #];
}
