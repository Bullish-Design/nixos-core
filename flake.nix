{
  description = "NixOS core modules (WSL only)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixos-wsl, ... }: {
    nixosModules = {
      wsl-upstream = nixos-wsl.nixosModules.default;
      common = import ./modules/common.nix;
      wsl = import ./modules/wsl.nix;
      tailscale = import ./modules/tailscale.nix;
      syncthing = import ./modules/syncthing.nix;
    };
  };
}
