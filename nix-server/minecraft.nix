{ config, pkgs, ... }:

{
    services.minecraft-server = {
        enable = true;
        eula = true;

        # Store world + configs here
        dataDir = "/var/lib/minecraft";

        # Make whitelist/ops/etc managed declaratively by NixOS
        declarative = true;

        # Restrict to whitelist
        serverProperties = {
            white-list = true;
            enforce-whitelist = true;
            # server-port = 25565; # optional
        };

        # Whitelist is a mapping: username -> UUID
        whitelist = {
            # Replace with einPfannkuchen's real UUID:
            einPfannkuchen = "282d2416-c08d-42aa-84ee-f16e0c230cc5";
        };

        # Optional: open firewall for the port
        openFirewall = true;
    };

    fileSystems."/home/nix/git/monorepo/data/minecraft" = {
        device = "/var/lib/minecraft";
        fsType = "none";
        options = [ "bind" ];
    };
}

