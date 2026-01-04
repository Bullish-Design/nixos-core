# AGENTS.md

## Repository Overview

**nixos-core** provides foundational NixOS modules for system-level configuration. Currently focused on WSL integration and common Nix settings.

## Architecture

```
flake.nix
    ├── nixosModules.wsl-upstream  → NixOS-WSL (passthrough)
    ├── nixosModules.common        → modules/common.nix
    └── nixosModules.wsl           → modules/wsl.nix
```

This is a thin wrapper that:
1. Re-exports `nixos-wsl` upstream module
2. Provides opinionated defaults via `common.nix`
3. Adds WSL-specific convenience via `wsl.nix`

## Making Changes

### Adding Options

Options live under `nixos-core.<module>` namespace:

```nix
options.nixos-core.<module> = {
  enable = mkEnableOption "<module>";
  
  someOption = mkOption {
    type = types.str;
    default = "value";
    description = "Description";
  };
};

config = mkIf config.nixos-core.<module>.enable {
  # Implementation
};
```

### Adding a New Module

1. Create `modules/<n>.nix`
2. Export in `flake.nix` under `nixosModules`
3. Document in README.md

## Constraints

- **NixOS modules only**: Home Manager modules belong in nix-terminal
- **System-level config**: Hardware, boot, services, not user environment
- **Options require explicit enable**: No automatic side effects on import
- **Namespace**: All options under `nixos-core.*`

## Integration Points

### Consumed by nix-meta

```nix
imports = [
  nixos-core.nixosModules.wsl-upstream  # Required for WSL
  nixos-core.nixosModules.common
  nixos-core.nixosModules.wsl
];

nixos-core.common.enableFlakes = true;
nixos-core.wsl.enable = true;
```

### Dependencies

- `nixpkgs` - Package collection
- `nixos-wsl` - Upstream WSL support (re-exported)

## Common Tasks

### Add experimental Nix feature
Update default in `modules/common.nix`:
```nix
experimentalFeatures = mkOption {
  default = [ "nix-command" "flakes" "new-feature" ];
};
```

### Add system package to defaults
Update `systemPackages` default in `modules/common.nix`.

### Add WSL-specific setting
Add to `modules/wsl.nix` config section:
```nix
config = mkIf config.nixos-core.wsl.enable {
  wsl.enable = true;
  wsl.newSetting = value;
};
```

## Testing

```bash
nix flake check

# Test in consumer
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --dry-run
```

## File Locations

| What | Where |
|------|-------|
| Flake definition | `flake.nix` |
| Common Nix settings | `modules/common.nix` |
| WSL integration | `modules/wsl.nix` |
