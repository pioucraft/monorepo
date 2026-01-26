{ config, pkgs, lib, ... }:

{
  # NVIDIA proprietary drivers (NixOS 25.11+ changes)
  hardware.nvidia = {
    modesetting.enable = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = false;  # Required for proprietary drivers >= 560
  };

  # X server configuration for NVIDIA
  services.xserver.videoDrivers = [ "nvidia" ];

  # OpenGL support (driSupport removed in newer NixOS)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
}

