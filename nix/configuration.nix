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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nathangasser = {
    isNormalUser = true;
    description = "Nathan Gasser";
    extraGroups = [ "networkmanager" "wheel" ];
    packages = with pkgs; [
    ];
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
  };


  programs.firefox.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
    brave
    gh
  ];

  system.stateVersion = "25.11"; # Did you read the comment?

}
