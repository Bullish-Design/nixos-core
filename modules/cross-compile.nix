# modules/cross-compile.nix — binfmt/qemu emulated systems (capability crossCompile).
# Greenfields the boot.binfmt block from .dotfiles/configuration.nix:33-34 into its
# own capability module.
{ config, lib, ... }:
let
  cfg = config.nixos-core.cross-compile;
in
{
  options.nixos-core.cross-compile = {
    enable = lib.mkEnableOption "binfmt/qemu emulated systems (cross-compile)";

    emulatedSystems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "aarch64-linux" ];
      description = "binfmt-emulated target systems (qemu).";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.binfmt.emulatedSystems = cfg.emulatedSystems;
    nix.settings.extra-platforms = config.boot.binfmt.emulatedSystems;
  };
}
