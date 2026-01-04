{ config, lib, pkgs, ... }:

with lib;

{
  options.nixos-core.common = {
    enableFlakes = mkOption {
      type = types.bool;
      default = true;
      description = "Enable experimental nix flakes and commands";
    };

    experimentalFeatures = mkOption {
      type = types.listOf types.str;
      default = [ "nix-command" "flakes" ];
      description = "List of experimental Nix features to enable";
    };

    systemPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      description = "Base system packages to install globally";
    };
  };

  config = mkIf config.nixos-core.common.enableFlakes {
    nix.settings.experimental-features = config.nixos-core.common.experimentalFeatures;
    environment.systemPackages = config.nixos-core.common.systemPackages;
  };
}
