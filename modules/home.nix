# /etc/nixos/home.nix
{ pkgs, ... }:

{
  # Set your username and home directory
  home.username = "void";
  home.homeDirectory = "/home/void";

  # Home Manager state version (match your NixOS installation release)
  home.stateVersion = "26.05";

  # Let Home Manager install and manage itself
  programs.home-manager.enable = true;

  services.kdeconnect.enable = true;

  systemd.user.services.kdeconnect = {
    Service = {
      # Force the Wayland or X11 display variables directly into the exec environment
      Environment = [
        "WAYLAND_DISPLAY=wayland-1" # Adjust if your socket is named differently
        "DISPLAY=:0" # Fallback for X11/XWayland
        "QT_QPA_PLATFORM=wayland" # Or 'xcb' if strictly X11
      ];

      # If you need to pass dynamic variables that aren't static strings,
      # you use ExecStartPre to write them to an EnvironmentFile, or pass them via PassEnvironment
    };
  };

  # Any other user-level packages you want
  #home.packages = with pkgs; [
  # fastfetch
  # ripgrep
  #];
}
