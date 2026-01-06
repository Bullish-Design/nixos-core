{ config, lib, ... }:

with lib;

{
  options.nixos-core.tailscale = {
    enable = mkEnableOption "Tailscale VPN service";
  };

  config = mkIf config.nixos-core.tailscale.enable {
    services.tailscale.enable = true;

    networking.firewall = {
      checkReversePath = "loose";
      trustedInterfaces = [ "tailscale0" ];
    };
  };
}
