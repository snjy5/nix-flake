# ./configuration.nix
{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/btrfs-snapshots.nix
  ];

  # ===========================================================================
  # 1. Nix & Flakes Settings
  # ===========================================================================
  nix = {
    channel.enable = false;
    nixPath = [ ];
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      fallback = false;
      max-jobs = 16;
    };
    gc = {
      automatic = true;
      dates = "weekly";
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowInsecurePredicate = pkg: (pkg.pname or pkg.name) == "broadcom-sta";
  };

  # ===========================================================================
  # 2. Home Manager Configuration
  # ===========================================================================
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.void = import ./modules/home.nix;
  };

  # ===========================================================================
  # 3. Boot & Hardware Options
  # ===========================================================================
  boot = {
    loader = {
      timeout = 5;
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        efiInstallAsRemovable = true;
        copyKernels = true;
        useOSProber = true;
      };
    };

    initrd = {
      kernelModules = [
        "btrfs"
        "i915"
      ];
      luks.devices."nixos" = lib.mkForce {
        device = "UUID=f919548e-79a7-4209-b51f-3e67689883ca";
        preLVM = true;
        allowDiscards = true;
      };
    };

    extraModprobeConfig = ''
      options v4l2loopback devices=1 exclusive_caps=1 video_nr=1 card_label="VirtualCam"
    '';

    supportedFilesystems = [
      "btrfs"
      "vfat"
    ];

    kernelModules = [
      "wl"
      "facetimehd"
      "v4l2loopback"
    ];

    blacklistedKernelModules = [
      "b43"
      "bcma"
      "brcmsmac"
      "ssb"
    ];

    extraModulePackages = with config.boot.kernelPackages; [
      broadcom_sta
      facetimehd
      v4l2loopback
    ];

    tmp = {
      useTmpfs = true;
      cleanOnBoot = true;
    };

    kernelParams = [
      "acpi_osi="
      "acpi_backlight=native"
      "elevator=bfq"
      "pcie_aspm=force"
      "loglevel=7"
      "audit=1"
      "debug"
      "zswap.enabled=1"
      "zswap.compressor=zstd"
      "zswap.max_pool_percent=70"
      "zswap.shrinker_enabled=1"
      "i915.enable_psr=0"
      "i915.enable_fbc=1"
    ];

    kernel.sysctl = {
      "vm.swappiness" = 5;
      "vm.oom_dump_tasks" = 1;
      "vm.panic_on_oom" = 0;
      "kernel.sched_autogroup_enabled" = 1;
      "kernel.sysrq" = 1;
    };
  };

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      extraPackages = [ pkgs.intel-vaapi-driver ];
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          FastConnectable = "true";
          AutoConnect = "true";
        };
      };
    };
    firmware = [ pkgs.facetimehd-firmware ];
    facetimehd.enable = true;
    pulseaudio.enable = false;
  };

  # ===========================================================================
  # 4. Filesystems & Swap
  # ===========================================================================
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

  # ===========================================================================
  # 5. Systemd & OOM Management
  # ===========================================================================
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

  # ===========================================================================
  # 6. System Services
  # ===========================================================================

  services = {
    dbus.enable = true;
    thermald.enable = true;
    upower.enable = true;
    fwupd.enable = true;
    fstrim.enable = true;
    libinput.enable = true;

    #displayManager.sddm = {
    #  enable = true;
    #  wayland.enable = true;
    #};

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
  };

  virtualisation.docker.enable = true;

  # ===========================================================================
  # 7. Networking, Time & Security (Root Level)
  # ===========================================================================
  networking = {
    hostName = "nixos";
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

  time.timeZone = "Asia/Kolkata";
  console.keyMap = "us";

  security = {
    rtkit.enable = true;
    pki.certificates = [ ];
    pam.services.swaylock = { };
    polkit.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland # Hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde # KDE Plasma
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  };

  # ===========================================================================
  # 8. Programs & Shell
  # ===========================================================================
  programs = {
    sway = {
      enable = true;
    };
    kdeconnect.enable = true;
    zsh.enable = true;
    adb.enable = true;
  };

  services.udev.extraRules =
    let
      # lsusb and get the id for each device
      # Motorola PCS XT1541 [Moto G 3rd Gen] 22b8:2e82
      idVendor = "22b8"; 
      idProduct = "2e82";
    in
    ''
      SUBSYSTEM=="usb", ATTR{idVendor}=="${idVendor}", MODE="[]", GROUP="adbusers", TAG+="uaccess"
      SUBSYSTEM=="usb", ATTR{idVendor}=="${idVendor}", ATTR{idProduct}=="${idProduct}", SYMLINK+="android_adb"
      SUBSYSTEM=="usb", ATTR{idVendor}=="${idVendor}", ATTR{idProduct}=="${idProduct}", SYMLINK+="android_fastboot"
    '';

  # add user to adbusers group
  users.users.void = {
    isNormalUser = true;
    extraGroups = [ "adbusers" ];
  };

  # ===========================================================================
  # 9. Environment & System Packages
  # ===========================================================================
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
      gnomeExtensions.pop-shell # tiling
      mupdf
      easyeffects

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

  # ===========================================================================
  # 10. Users
  # ===========================================================================
  users.users = {
    root.initialPassword = "1234";
    void = {
      isNormalUser = true;
      initialPassword = "1234";
      shell = pkgs.zsh;
      extraGroups = [
        "wheel"
        "networkmanager"
        "audio"
        "video"
        "input"
        "docker"
      ];
    };
  };

  system.stateVersion = "26.05";
}
