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
