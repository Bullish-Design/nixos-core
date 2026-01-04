{ config, lib, ... }:

with lib;

{
  options.nixos-core.wsl = {
    enable = mkEnableOption "NixOS-WSL integration";
  };

  config = mkIf config.nixos-core.wsl.enable {
    wsl.enable = true;
  };
}
