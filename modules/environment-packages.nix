{
  config,
  pkgs,
  lib,
  ...
}:

{
  environment = {
    sessionVariables = {
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_STATE_HOME = "$HOME/.local/state";
      XDG_CACHE_HOME = "$HOME/.cache";
    };
    systemPackages = with pkgs; [
      # Core utilities
      git
      file
      htop
      wget
      curl
      neovim
      tmux
      stress
      cacert

      # Hardware/Disk
      libinput
      btrfs-progs
      efibootmgr
      pciutils
      usbutils
      smartmontools
      e2fsprogs
      tlp
      powertop

      # Wayland tools
      wl-clipboard
      fuzzel
      brightnessctl
      gammastep
      bemenu
      j4-dmenu-desktop
      swaybg
      swayidle
      swaylock
      foot
      waybar
      wf-recorder

      # Apps & Media
      firefox
      microsoft-edge
      pamixer
      pwvucontrol
      mako
      grim
      slurp
      telegram-desktop
      gnomeExtensions.gsconnect
      gnomeExtensions.pop-shell
      mupdf
      easyeffects
      links2
      upwork

      # Video rendering
      v4l-utils
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly
      gst_all_1.gst-libav
      gst_all_1.gst-vaapi
      intel-media-driver
      mesa
      libvdpau-va-gl
      wlr-randr
      ffmpeg-full
      mpv
      obs-studio
      snapshot

      # Development
      nixd
      nixfmt
      gcc
      zola
      python3
      nodejs
      go
      unzip
      imv
      terraform
      ansible
      android-tools
      dmidecode

      # Office
      pandoc
      texliveSmall
    ];
  };

  fonts = {
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      font-awesome
      jetbrains-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.symbols-only
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrains Mono" ];
      sansSerif = [ "Noto Sans" ];
      serif = [ "Noto Serif" ];
    };
  };
}
