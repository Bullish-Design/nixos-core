# nixos-core

## Usage

Import the module and configure via options:

```nix
{
  imports = [
    inputs.nixos-core.nixosModules.common
  ];

  nixos-core.common = {
    enableFlakes = true;
    experimentalFeatures = [ "nix-command" "flakes" ];
    systemPackages = with pkgs; [ git vim ];
  };
}
```

## New Modules

### Tailscale (`nixosModules.tailscale`)

VPN service configuration with firewall rules.

### Syncthing (`nixosModules.syncthing`)

File synchronization with configurable devices and folders.

## Usage

```nix
{
  imports = [
    inputs.nixos-core.nixosModules.common
    inputs.nixos-core.nixosModules.tailscale
    inputs.nixos-core.nixosModules.syncthing
  ];

  nixos-core = {
    common.enableFlakes = true;

    tailscale.enable = true;

    syncthing = {
      enable = true;
      user = "andrew";
      dataDir = "/home/andrew";
      configDir = "/home/andrew/.config/syncthing";

      devices = {
        pi = {
          id = "DEVICE-ID-HERE";
          introducer = true;
        };
      };

      folders = {
        notes = {
          path = "/home/andrew/Documents/Notes";
          devices = [ "pi" ];
          ignorePerms = true;
        };
      };
    };
  };
}
```

## Breaking Changes

### v1.0 → v2.0

Consumers must now configure options explicitly under the `nixos-core` namespace.

**Before:**

```nix
imports = [ inputs.nixos-core.nixosModules.common ];
```

**After:**

```nix
imports = [ inputs.nixos-core.nixosModules.common ];

nixos-core.common = {
  enableFlakes = true;
  systemPackages = with pkgs; [ git ];
};
```
