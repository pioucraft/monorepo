{ config, pkgs, ... }:

let
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
in

{
    imports =
        [ # Include the results of the hardware scan.
        ./hardware-configuration.nix
            ./temp.nix
            (import "${home-manager}/nixos")
        ];

    nix.nixPath = [
        "nixos-config=/home/nathangasser/git/monorepo/nix/configuration.nix"  # Your desired default path
            "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    ];

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    networking.hostName = "nixos"; # Define your hostname.

    # Enable networking
        networking.networkmanager.enable = true;

    time.timeZone = "Europe/Zurich";

    # Select internationalisation properties.
    i18n.defaultLocale = "en_US.UTF-8";

    # Enable the X11 windowing system.
    services.xserver.enable = true;

    # Enable the GNOME Desktop Environment.
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Configure keymap in X11
    services.xserver.xkb = {
        layout = "ch";
        variant = "fr";
    };

    # Configure console keymap
    console.keyMap = "fr_CH";

    # Enable CUPS to print documents.
    services.printing.enable = true;

    # Enable sound with pipewire.
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
    };

    users.users.nathangasser = {
        isNormalUser = true;
        description = "Nathan Gasser";
        extraGroups = [ "networkmanager" "wheel" ];
    };

    home-manager.users.nathangasser = { pkgs, ... }: {
        home.username = "nathangasser";
        home.homeDirectory = "/home/nathangasser";
        home.stateVersion = "25.11";

        programs.git = {
            enable = true;
            settings = {
                user.name = "Nathan Gasser";
                user.email = "hello@gougoule.ch";
            };
        };

        wayland.windowManager.hyprland = {
            enable = true;
            settings = {
                decoration = {
                    active_opacity = "0.95";
                    inactive_opacity = "0.9";
                };

                misc = {
                    force_default_wallpaper = 0;
                    disable_hyprland_logo = true;
                };

                "$mod" = "SUPER";
                "$terminal" = "ghostty";
                "$browser" = "xdg-open https://";
                bind = [
                    "$mod, Return, exec, $terminal"
                    "$mod, Space, exec, wofi --show drun"
                    "$mod, B, exec, $browser"
                    "$mod, Q, killactive"
                ]
                ++ (
                    builtins.concatLists (builtins.genList (i:
                        let ws = i + 1;
                            in [
                                "$mod, code:1${toString i}, workspace, ${toString ws}"
                                "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
                            ]
                        )
                    9)
                  );
                input = {
                    kb_layout = "ch";
                    kb_variant = "fr";
                };
            };
            extraConfig = ''
                animations {
                    enabled = 0
                }
            '';

        };

        home.pointerCursor = {
            gtk.enable = true;
            package = pkgs.bibata-cursors;
            name = "Bibata-Modern-Classic";
            size = 16;
        };

        gtk = {
            enable = true;

            theme = {
                package = pkgs.gnome-themes-extra;
                name = "Adwaita-dark";
            };

            iconTheme = {
                package = pkgs.adwaita-icon-theme;
                name = "Adwaita";
            };

            font = {
                name = "Sans";
                size = 11;
            };
        };

    };


    programs.firefox.enable = true;
    programs.hyprland.enable = true;

    nixpkgs.config.allowUnfree = true;

    environment.systemPackages = with pkgs; [
        vim
            git
            brave
            gh
            ghostty
            fastfetch
            pavucontrol
            wofi
    ];

    system.stateVersion = "25.11"; # Did you read the comment?

}
