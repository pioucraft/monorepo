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

    virtualisation.libvirtd.enable = true;

    boot.kernelModules = [ "hid-playstation" "kvm-intel" "kvm" ];

    hardware.bluetooth = {
        enable = true;
        powerOnBoot = true;

        # Writes /etc/bluetooth/input.conf
        input.General = {
            UserspaceHID = "true";
        };
    };
    services.udev.extraRules = ''
    # Sony DualSense (USB)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"

    # Sony DualSense (Bluetooth)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="0005:054C:0CE6.*", MODE="0660", TAG+="uaccess"
    '';


    programs.virt-manager.enable = true;

    users.users.nathangasser.extraGroups = [ "libvirtd" "kvm" ];


    environment.systemPackages = with pkgs; [
        steam
    ];

}

