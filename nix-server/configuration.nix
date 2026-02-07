{ config, pkgs, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/release-25.11.tar.gz";
  nixvim = import (builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      ref = "nixos-25.11";
  });

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
    ];
    services.openssh.settings.PasswordAuthentication = false;

    environment.systemPackages = with pkgs; [
        vim
        git
        fastfetch
    ];

    system.stateVersion = "25.05";
}
