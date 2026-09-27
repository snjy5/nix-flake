{
  config,
  pkgs,
  lib,
  globals,
  ...
}:

{
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
        "applesmc"
        "coretemp"
      ];
      luks.devices."nixos" = lib.mkForce {
        device = "UUID=${globals.luksUuid}";
        preLVM = true;
        allowDiscards = true;
      };
    };

    extraModprobeConfig = ''
      options v4l2loopback devices=1 exclusive_caps=1 video_nr=1 card_label="VirtualCam"
      options facetimehd pcie_aspm=0
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
      extraPackages = with pkgs; [
        intel-media-driver
        libvdpau-va-gl
      ];
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

    facetimehd = {
      enable = true;
      withCalibration = true;
    };

    pulseaudio.enable = false;
  };
}
