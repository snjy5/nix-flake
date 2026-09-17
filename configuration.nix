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
                # Note: <home-manager/nixos> has been removed here because angle-bracket
                # channel lookups are incompatible with Flakes. You must pass the Home
                # Manager module through your flake.nix instead.

        ];

        # 3. Configure Home Manager
        home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                users.void = import ./modules/home.nix; # Points to the modular home.nix
        };

        # Prevents nix-channel from working and stops Nix from
        # falling back to <nixpkgs> lookups
        nix.channel.enable = false;

        # Optional but recommended: Explicitly disable the legacy
        # NIX_PATH environment variable that channels rely on
        nix.nixPath = [ ];

        # ===========================================================================
        # 1. Boot & Hardware Options
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
                # Add applesmc-next to extra module packages
                extraModulePackages = with config.boot.kernelPackages; [
                        broadcom_sta
                        facetimehd
                        v4l2loopback
                ];

                tmp = {
                        useTmpfs = true;
                        cleanOnBoot = true;
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

                # Disable legacy PulseAudio if it's enabled
                pulseaudio.enable = false;
        };

        # ===========================================================================
        # 2. Filesystems & Swap
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

        # Memory management
        # Ensure systemd tracks memory accounting for user sessions
        systemd.user.extraConfig = ''
                DefaultMemoryAccounting=yes
        '';

        boot.kernelParams = [
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
                "i915.enable_fbc=1" # Framebuffer compression, usually fine, helps perf
        ];

        # Memory management
        # 1. Enable the systemd-oomd daemon
        systemd.oomd.enable = true;

        # 2. Enable cgroup pressure stall information monitoring
        # (systemd-oomd relies on PSI, which requires cgroups v2 and pressure metrics)
        systemd.oomd.enableUserSlices = true;
        systemd.oomd.enableSystemSlice = true;

        systemd.slices."user-".sliceConfig = {
                # --- NO KILLING ---
                ManagedOOMMemoryPressure = "auto";
                ManagedOOMSwap = "auto";

                # --- NO HARD CAPS (no stall, no ENOMEM) ---
                # Do NOT set MemoryMax or MemoryHigh
                # Without these, the kernel never blocks allocations

                # --- UNLIMITED SWAP ---
                MemorySwapMax = "infinity";

                # --- PROTECT DESKTOP RESPONSIVENESS ---
                MemoryLow = "512M";
        };

        boot.kernel.sysctl = {
                # Swappiness: higher = prefer swapping anonymous pages over dropping file cache
		# Let it only swap when absolutely needed
                "vm.swappiness" = 5;

                # Min free Kbytes: keep more headroom so direct reclaim rarely triggers
                # Prevents allocation stalls by ensuring kswapd handles everything proactively
                #"vm.min_free_kbytes" = 262144; # 256MB; adjust based on total RAM

                # 0 = Heuristic overcommit handling (default)
                # 2 = Strict overcommit (allocations fail before physical RAM+swap runs out)
                #"vm.overcommit_memory" = 0;

                # Dump the process memory map and page cache state to dmesg when OOM killer triggers
                "vm.oom_dump_tasks" = 1;

                # 0 = Kill the process causing the OOM (default)
                # 1 = Panic the kernel immediately on OOM (useful for headless/clustered failovers)
                "vm.panic_on_oom" = 0;

                # If vm.panic_on_oom = 1, reboot the machine after 10 seconds
                # "kernel.panic" = 10;

                # Reduce boost magnitude to limit kswapd CPU spikes during bursts
                # Default: 15000 (15%). Lower = gentler proactive reclaim.
                # 5000 = 5% boost: enough to prevent direct reclaim,
                # mild enough to avoid noticeable latency from kswapd itself.
                #"vm.watermark_boost_factor" = 5000;

                # Complement: ensure base watermarks are healthy so boost
                # has a reasonable foundation to work from
                #"vm.watermark_scale_factor" = 100; # wider gap between min/low/high

                # Background flush starts early; NVMe handles concurrent small writes well
                #"vm.dirty_background_bytes" = 134217728; # 128 MB

                # Generous cap; NVMe can drain this quickly without stalling writers
                #"vm.dirty_bytes" = 536870912; # 512 MB

                # Frequent wakeups keep dirty pages flowing steadily
                #"vm.dirty_writeback_centisecs" = 500; # 5s

                # Pages eligible for writeback after 10s (matches wakeup interval × 2)
                #"vm.dirty_expire_centisecs" = 1000; # 10s

                # Enable automatic process group scheduling (usually enabled by default in NixOS, but good to enforce)
                "kernel.sched_autogroup_enabled" = 1;

                # Enable Magic SysRq keys (1 = enable all functions)
                "kernel.sysrq" = 1;

        };

        # Zram
        #zramSwap = {
        #  enable = true;
        #  algorithm = "zstd";
        #  memoryPercent = 70; # Allocates a zram swap device equal to 70% of RAM, zswap uses 10% leaving 10% for oom safety
        #  priority = 5; # Higher priority than disk swap (defaults to 5)
        #};

        # ===========================================================================
        # 3. System Services
        # ===========================================================================
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

                                # Prevent TLP from enabling runtime PM that might cause issues
                                USB_AUTOSUSPEND_DISABLE_ON_STARTUP = 1;

                                # Keep WiFi/Bluetooth active (prevents connectivity "suspend")
                                WIFI_DISABLE_ON_LID_CLOSE = 0;
                                BLUETOOTH_DISABLE_ON_LID_CLOSE = 0;

                                # MacBooks only support a Stop threshold in hardware (BCLM).
                                # TLP will automatically enforce the stop threshold.
                                START_CHARGE_THRESH_BAT0 = 75;
                                STOP_CHARGE_THRESH_BAT0 = 80;
                        };
                };

                pipewire = {
                        enable = true;
                        pulse.enable = true; # for apps that require PulseAudio compatibility
                        alsa = {
                                enable = true;
                                support32Bit = true;
                        };
                        jack.enable = true;
                        wireplumber.enable = true;
                };

                # keyd = {
                #  enable = true;
                #  keyboards.default = {
                #    ids = [ "*" ];
                #    settings = {
                #      main = {
                #        leftalt = "leftmeta";
                #        leftmeta = "leftalt";
                #        rightalt = "rightmeta";
                #        rightmeta = "rightalt";
                #      };
                #    };
                #  };
                # };

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

                # Enable Nginx web server
                nginx = {
                        enable = true;

                        # Define a virtual host bound strictly to localhost
                        virtualHosts."localhost" = {
                                listen = [
                                        {
                                                addr = "127.0.0.1";
                                                port = 80;
                                        }
                                ];

                                # Optional: Set a custom root directory for your test files
                                # root = "/home/void/test-www";

                                # Optional: Serve a simple index.html by default
                                locations."/" = {
                                        root = "/srv/http"; # Default NixOS nginx root
                                        index = "index.html";
                                };
                        };
                };
        };

        virtualisation.docker.enable = true;

        # ===========================================================================
        # 4. Networking, Time & Security
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
                pam.services.swaylock = { };
                pki.certificates = [ ];
                polkit.enable = true;
        };

        xdg.portal = {
                enable = true;
                wlr.enable = true;
                extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
        };

        programs = {
                sway = {
                        enable = true;
                        extraPackages = [ ];
                };
                kdeconnect.enable = true;
                zsh.enable = true;
        };

        # ===========================================================================
        # 5. Environment & Packages
        # ===========================================================================
        nix = {
                settings = {
                        auto-optimise-store = true;
                        experimental-features = [
                                "nix-command"
                                "flakes"
                        ];
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

        environment = {
                sessionVariables = {
                        MOZ_ENABLE_WAYLAND = "1";
                        NIXOS_OZONE_WL = "1";
                        WLR_NO_HARDWARE_CURSORS = "1"; # Fixes cursor tearing/stuttering on older Intel
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

                        # Wayland/Sway
                        xwayland
                        sway
                        foot
                        wayland
                        wl-clipboard
                        swaybg
                        swayidle
                        swaylock
                        bemenu
                        j4-dmenu-desktop
                        fuzzel
                        brightnessctl

                        # Apps & Media
                        firefox
                        microsoft-edge
                        #google-chrome
                        pamixer
                        pwvucontrol
                        waybar
                        mako
                        lxqt.lxqt-policykit
                        grim
                        slurp

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
                        snapshot # gnome snapshot

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

                        # kde
                        kdePackages.kdeconnect-kde
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

        nix.settings = {
        # Fail immediately if a binary substitute is not available
        fallback = false;
        # (Optional) Restrict builder jobs system-wide if 0
        max-jobs = 16;
        };

        # ===========================================================================
        # 6. Users
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
                                "void"
                        ];
                };
        };

        systemd.sleep.settings.Sleep = {
                AllowSuspend = "no";
                AllowHibernation = "no";
                AllowHybridSleep = "no";
                AllowSuspendThenHibernate = "no";
        };

        system.stateVersion = "26.05";
}
