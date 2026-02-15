{ config, pkgs, lib, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  nixvim = import (builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      ref = "nixos-25.11";
  });
  server-software = import ../server-software { inherit pkgs; };

in
{
    imports = [
        ./hardware-configuration.nix 
        (import "${home-manager}/nixos")
        nixvim.nixosModules.nixvim
    ];

    programs.nixvim.enable = true;
    home-manager.extraSpecialArgs = { inherit nixvim; };  # Passes nixvim to user configs

    boot.loader.grub.enable = true;
    boot.loader.grub.device = "/dev/sda";

    nix.nixPath = [
        "nixos-config=/home/nix/git/monorepo/nix-server/configuration.nix"  # Your desired default path
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"
    ];

    networking.hostName = "nixos";

    time.timeZone = "Europe/Zurich";

    users.users.nix = {
        isNormalUser = true;
        extraGroups = [ "networkmanager" "wheel" ];
    };

    home-manager.users.nix = { pkgs, ... }: {
        imports = [
            nixvim.homeModules.nixvim
        ];

        home.username = "nix";
        home.homeDirectory = "/home/nix";
        home.stateVersion = "25.11";
        nixpkgs.config.allowUnfree = true;

        programs.nixvim = {
            enable = true;
            nixpkgs.config.allowUnfree = true;

            colorschemes.gruvbox.enable = true;

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
    };

    services.openssh.enable = true;
    users.users.nix.openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC1Gr/WhLeFAJKty2CiCcn0Wc5ld2fJF7lRhGW5DVjxd nathangasser@nixos"
        "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLsh0zXGiB3PObOO1p1nQk8yybMynBxOj2fyemuxWQiRNrNTwKwisQ7qCi7+HkrPbozsOMCPoKaQ0W44D8D/MDQ= #ssh.id - @pioucraft"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDy4otgTxM1yu3UGsdpgUVLky6GFp0Z3bAyFaIo9pxtH nathangasser@nixos" # Laptop
    ];
    services.openssh.settings.PasswordAuthentication = false;

    environment.systemPackages = with pkgs; [
        vim
        git
        fastfetch
        awscli2
        gnutar
        curl
        eyed3
    ];

    # Journal app
    systemd.services.server-software = {
        description = "Journal Server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
            ExecStart = "${server-software}/bin/server-software";
            WorkingDirectory = "/home/nix/git/monorepo/server-software";
            EnvironmentFile = "/home/nix/git/monorepo/server-software/.env";
            Restart = "always";
            User = "nix";
        };
    };

    # Telegram bot
    systemd.services.telegram-bot = {
        description = "Telegram Bot";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
            ExecStart = "${pkgs.bun}/bin/bun /home/nix/git/monorepo/telegram-bot/bot.js";
            WorkingDirectory = "/home/nix/git/monorepo/telegram-bot";
            EnvironmentFile = "/home/nix/git/monorepo/nix-server/.env";
            Restart = "always";
            User = "root";
            Environment = "PATH=/run/current-system/sw/bin:/bin:/usr/bin:/usr/local/bin";

        };
    };

    # Data backup to Cloudflare R2
    systemd.services.data-backup = {
        description = "Backup data to Cloudflare R2";
        path = with pkgs; [ gnutar gzip awscli2 ];
        serviceConfig = {
            Type = "oneshot";
            ExecStart = "/home/nix/git/monorepo/nix-server/backup.sh";
            User = "nix";
        };
        unitConfig = {
            OnSuccess = "data-backup-notify-success.service";
            OnFailure = "data-backup-notify-failure.service";
        };
    };

    systemd.services.data-backup-notify-success = {
        description = "Notify Telegram of successful backup";
        path = with pkgs; [ curl coreutils ];
        serviceConfig = {
            Type = "oneshot";
            ExecStart = "/home/nix/git/monorepo/nix-server/telegram-notify.sh '✅ Backup completed successfully'";
            User = "nix";
        };
    };

    systemd.services.data-backup-notify-failure = {
        description = "Notify Telegram of failed backup";
        path = with pkgs; [ curl coreutils ];
        serviceConfig = {
            Type = "oneshot";
            ExecStart = "/home/nix/git/monorepo/nix-server/telegram-notify.sh '❌ Backup failed'";
            User = "nix";
        };
    };

    systemd.timers.data-backup = {
        description = "Run data backup every 12 hours";
        wantedBy = [ "timers.target" ];
        timerConfig = {
            OnCalendar = "*-*-* 00,12:00:00";
            Persistent = true;
        };
    };

    services.navidrome = {
        enable = true;
        settings = {
            Address = "0.0.0.0"; # Or a specific IP
            Port = 4533;
            MusicFolder = "/home/nix/git/monorepo/data/music";
        };
    };
    systemd.services.navidrome.serviceConfig.ProtectHome = lib.mkForce "read-only";

    # WireGuard VPN Container
    containers.wireguard = {
        autoStart = true;
        privateNetwork = true;
        hostAddress = "192.168.100.10";
        localAddress = "192.168.100.11";
        
        allowedDevices = [
            { node = "/dev/net/tun"; modifier = "rwm"; }
        ];
        
        additionalCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        
        bindMounts = {
            "/etc/wireguard/wg0.conf" = {
                hostPath = "/home/nix/git/monorepo/nix-server/wireguard.conf";
                isReadOnly = true;
            };
            "/home/nix/git/monorepo/" = {
                hostPath = "/home/nix/git/monorepo/";
                isReadOnly = false;
            };
        };
        
        config = { config, pkgs, ... }: {
system.stateVersion = "25.05";

  # Allow user 'nix' to run the download-music script as root without a password.
  security.sudo.extraRules = [
    {
      users = [ "nix" ];
      commands = [
        {
          command = "/home/nix/git/monorepo/nix-server/download-music.sh";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

            # Grant group containers access to ns paths so host user can nsenter

            
            # Enable WireGuard kernel module support
            boot.kernelModules = [ "wireguard" ];
            
            # Install WireGuard tools
            environment.systemPackages = with pkgs; [
            wireguard-tools
            curl
            yt-dlp
            eyed3
        ];

            # Enable systemd-resolved so wg-quick can set DNS
services.resolved.enable = true;
    networking.useHostResolvConf = false;
    networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

            # Set up WireGuard interface using wg-quick
            systemd.services.wireguard-setup = {
                description = "Setup WireGuard VPN";
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = "${pkgs.wireguard-tools}/bin/wg-quick up /etc/wireguard/wg0.conf";
                    ExecStop = "${pkgs.wireguard-tools}/bin/wg-quick down /etc/wireguard/wg0.conf";
                };
            };
            
            # Wait for WireGuard to be ready before considering network up
            systemd.services.wait-for-vpn = {
                description = "Wait for WireGuard VPN";
                after = [ "wireguard-setup.service" "network-online.target" ];
                requires = [ "wireguard-setup.service" ];
                wantedBy = [ "multi-user.target" ];
                serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = pkgs.writeShellScript "wait-for-vpn" ''
                        for i in $(seq 1 30); do
                            if ${pkgs.wireguard-tools}/bin/wg show wg0 &>/dev/null; then
                                echo "WireGuard interface is up"
                                break
                            fi
                            echo "Waiting for WireGuard... ($i/30)"
                            sleep 1
                        done
                    '';
                };
            };
        };
    };

    # Caddy reverse proxy
    services.caddy = {
        enable = true;
        virtualHosts."home.gougoule.ch" = {
            extraConfig = ''
                reverse_proxy localhost:3000
            '';
        };
        virtualHosts."navidrome.gougoule.ch" = {
            extraConfig = ''
                reverse_proxy localhost:4533
            '';
        };
    };

    boot.kernel.sysctl."net.ipv4.ip_forward" = true;

    networking.firewall = {
        allowedTCPPorts = [ 80 443 22 ];
        extraCommands = ''
          iptables -t nat -A POSTROUTING -s 192.168.100.0/24 -j MASQUERADE
          iptables -A FORWARD -s 192.168.100.0/24 -j ACCEPT
          iptables -A FORWARD -d 192.168.100.0/24 -m state --state RELATED,ESTABLISHED -j ACCEPT
        '';
    };

    system.stateVersion = "25.05";

}
