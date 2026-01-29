{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./apple-silicon-support
    ];

  # LUKS config (thanks Perplexity)
  boot.initrd.availableKernelModules = ["usb_storage"];
  boot.initrd.kernelModules = ["dm-crypt" "xts" "usbhid" "ext4" "dm-snapshot"];
  fileSystems."/" = {
    device = "/dev/mapper/luks-root";
    fsType = "ext4";
  };

  networking.wireless.iwd = {
    enable = true;
    settings.General.EnableNetworkConfiguration = true;
  };
}

