{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  nixvim = import (builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      ref = "nixos-25.11";
  });

in
{
    imports =
        [ # Include the results of the hardware scan.
        ./hardware-configuration.nix
        ./temp.nix
        (import "${home-manager}/nixos")
        nixvim.nixosModules.nixvim
        ];

    nix.nixPath = [
        "nixos-config=/home/nathangasser/git/monorepo/nix/configuration.nix"  # Your desired default path
            "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    ];

    nixpkgs.config.allowUnfree = true;
    programs.nixvim.enable = true;
    home-manager.extraSpecialArgs = { inherit nixvim; };  # Passes nixvim to user configs

    # Bootloader.
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    boot.enableContainers = true;

    networking.hostName = "nixos"; # Define your hostname.
    services.resolved.enable = true;
    networking.nameservers = ["1.1.1.1" "8.8.8.8"];

    # Enable networking
    networking.networkmanager.enable = true;

    networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 53317 ];
        allowedUDPPorts = [ 53317 ];
    };


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
        imports = [
            nixvim.homeModules.nixvim
        ];

        home.username = "nathangasser";
        home.homeDirectory = "/home/nathangasser";
        home.stateVersion = "25.11";
        nixpkgs.config.allowUnfree = true;

        programs.nixvim = {
            enable = true;
            nixpkgs.config.allowUnfree = true;

            globals.mapleader = " ";
            colorschemes.gruvbox.enable = true;
            plugins.copilot-vim.enable = true;
            # fuzzy finder
            plugins.telescope = {
                enable = true;
                settings = {
                    defaults = {
                        file_ignore_patterns = [ "node_modules" "dist" ".git" ];
                        vimgrep_arguments = [
                            "${pkgs.ripgrep}/bin/rg"
                            "--color=never"
                            "--no-heading"
                            "--with-filename"
                            "--line-number"
                            "--column"
                            "--smart-case"
                            "--hidden"
                            "--glob=!.git/"
                        ];
                    };
                };
                extensions.fzf-native.enable = true;
            };
            plugins.web-devicons.enable = true;
            # file explorer
            plugins.nvim-tree = {
                enable = true;
                settings = {
                    respect_buf_cwd = true;
                    sync_root_with_cwd = true;
                };
            };
            # keymaps for fuzzy finder + <leader> e for file explorer
            keymaps = [
                { key = "<leader>f"; action = "<cmd>Telescope find_files<CR>"; options.desc = "Find files"; }
                { key = "<leader>g"; action = "<cmd>Telescope live_grep<CR>"; options.desc = "Live grep"; }
                { key = "<leader>e"; action = "<cmd>NvimTreeToggle<CR>"; options.desc = "Toggle file explorer"; }
            ];


            opts = {
                expandtab = true;
                shiftwidth = 4;
                tabstop = 4;
                number = true;
                relativenumber = true;
            };

            plugins.treesitter = {
                enable = true;
                grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
                    nix
                    c
                    svelte
                    css
                    html
                    javascript
                    typescript
                    json
                ];
                settings = {
                    highlight.enable = true;
                    indent.enable = true;
                    # More: autotag.enable = true;
                };
            };

            plugins.lsp = {
                enable = true;
                inlayHints = true;
                servers = {
                    nixd.enable = true;
                    clangd.enable = true;
                    svelte.enable = true;
                    tailwindcss.enable = true;
                };
            };

            plugins.cmp-nvim-lsp.enable = true;

            plugins.cmp = {
                enable = true;  
                settings.sources = [
                    { name = "nvim_lsp"; }  # LSP completions first
                ];


                settings.mapping = {
                    "<C-Space>" = "cmp.mapping.complete()";
                    "<C-l>" = "cmp.mapping.confirm({ select = true })";
                    "<C-j>" = ''
    cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
      else
        fallback()
      end
    end, { 'i', 's' })
                    '';
                    "<C-k>" = ''
    cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
      else
        fallback()
      end
    end, { 'i', 's' })
                    '';
                };
            };
        };

        programs.git = {
            enable = true;
            settings = {
                user.name = "Nathan Gasser";
                user.email = "hello@gougoule.ch";
            };
        };

        programs.waybar = {
            enable = true;
            systemd.enable = true;  # Auto-starts with your Wayland session
            settings = [
                {
                    layer = "top";
                    modules-left = [ "hyprland/workspaces" ];
                    modules-center = [ "clock" ];
                    modules-right = [ "pulseaudio" "cpu" "battery" "memory" ];
                    battery = {
                        format = "{capacity}% {icon}";
                        format-icons = [ "" "" "" "" "" ];
                    };
                    clock = {
                        format = " {:%a, %d. %b  %H:%M:%S} ";
                        interval = 1;
                    };
                    cpu = {
                        interval = 1;
                        format = "{icon0}{icon1}{icon2}{icon3}{icon4}{icon5}{icon6}{icon7}";
                        format-icons = [ "▁" "▂" "▃" "▄" "▅" "▆" "▇" "█" ];
                    };
                    memory = {
                        interval = 1;
                        format = "{used:0.1f}G/{total:0.1f}G";
                    };
                    pulseaudio = {
                        format = "{volume}% {icon}";
                        format-bluetooth = "{volume}% {icon}";
                        format-muted = "";
                        format-icons = {
                            "alsa_output.pci-0000_00_1f.3.analog-stereo" = "";
                            "alsa_output.pci-0000_00_1f.3.analog-stereo-muted" = "";
                            headphone = "";
                            "hands-free" = "";
                            headset = "";
                            phone = "";
                            "phone-muted" = "";
                            portable = "";
                            car = "";
                            default = [ "" "" ];
                        };
                        scroll-step = 1;
                        on-click = "pavucontrol";
                        ignored-sinks = [ "Easy Effects Sink" ];
                    };
                    "hyprland/workspaces" = {
                        format = "{name}: {icon}";
                        format-icons = {
                            active = "";
                            default = "";
                        };
                    };
                }
            ];
            style = ''
      * {
        border: none;
        border-radius: 0;
        background: transparent;
        color: unset;
      }

      window#waybar {
        background-color: transparent;
        border-bottom: none;
        box-shadow: none;
      }

      #waybar.empty {
        background-color: transparent;
      }

      .modules-left, .modules-center, .modules-right {
        background-color: #0f0f0f;
        border-radius: 6px;
        margin: 5px;
        padding: 3px;
      }

      #pulseaudio {
        margin-left: 10px;
      }

      #cpu {
        margin-left: 10px;
        margin-right: 10px;
      }

      #battery {
        margin-left: 10px;
        margin-right: 10px;
      }

      #memory {
        margin-right: 10px;
      }
            '';

        };

        wayland.windowManager.hyprland = {
            enable = true;
            settings = {
                decoration = {
                    active_opacity = "0.95";
                    inactive_opacity = "0.9";
                    blur = {
                        enabled = false;
                    };
                };

                exec-once = [
                    "swaybg -i $HOME/git/monorepo/nix/wallpapers/$(ls $HOME/git/monorepo/nix/wallpapers | shuf -n 1)"
                ];

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
                    "$mod, F, togglefloating"
                    "$mod Control, l, exec, hyprlock"
                    ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
                    ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
                    ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
                    ", XF86AudioPlay, exec, playerctl play-pause"
                    ", XF86AudioPrev, exec, playerctl previous"
                    ", XF86AudioNext, exec, playerctl next"
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

                bindm = [
                    "$mod, mouse:272, movewindow"
                    "$mod, mouse:273, resizewindow"
                ];
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
    services.mullvad-vpn.enable = true;

    environment.systemPackages = with pkgs; [
        vim
        git
        brave
        gh
        ghostty
        fastfetch
        pavucontrol
        wofi
        hyprlock
        playerctl
        waybar
        localsend
        font-awesome_6
        swaybg
        clang-tools
        gcc
        nixd
        bun
        opencode
        uv
        mullvad-vpn
    ];

    system.stateVersion = "25.11"; # Did you read the comment?

}
