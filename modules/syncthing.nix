{ config, lib, ... }:

with lib;

{
  options.nixos-core.syncthing = {
    enable = mkEnableOption "Syncthing file synchronization";

    user = mkOption {
      type = types.str;
      description = "User running Syncthing service";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group owning Syncthing data";
    };

    dataDir = mkOption {
      type = types.str;
      description = "Syncthing data directory";
    };

    configDir = mkOption {
      type = types.str;
      description = "Syncthing configuration directory";
    };

    guiAddress = mkOption {
      type = types.str;
      default = "127.0.0.1:8384";
      description = "Syncthing web GUI address";
    };

    openDefaultPorts = mkOption {
      type = types.bool;
      default = true;
      description = "Open default Syncthing ports in firewall";
    };

    devices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            type = types.str;
            description = "Device ID";
          };
          introducer = mkOption {
            type = types.bool;
            default = false;
            description = "Whether this device is an introducer";
          };
        };
      });
      default = {};
      description = "Syncthing devices";
    };

    folders = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          path = mkOption {
            type = types.str;
            description = "Folder path";
          };
          devices = mkOption {
            type = types.listOf types.str;
            description = "List of device names to sync with";
          };
          ignorePerms = mkOption {
            type = types.bool;
            default = false;
            description = "Ignore file permissions";
          };
        };
      });
      default = {};
      description = "Syncthing folders";
    };
  };

  config = mkIf config.nixos-core.syncthing.enable {
    services.syncthing = {
      enable = true;
      user = config.nixos-core.syncthing.user;
      group = config.nixos-core.syncthing.group;
      dataDir = config.nixos-core.syncthing.dataDir;
      configDir = config.nixos-core.syncthing.configDir;
      guiAddress = config.nixos-core.syncthing.guiAddress;
      openDefaultPorts = config.nixos-core.syncthing.openDefaultPorts;

      settings = {
        devices = config.nixos-core.syncthing.devices;
        folders = config.nixos-core.syncthing.folders;
      };
    };
  };
}
