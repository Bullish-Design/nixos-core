# nixos-core

`nixos-core` provides composable, system-level NixOS modules. The canonical
foundation tier is `nixos-core.base`; user-environment policy belongs in a
consumer such as `nix-meta`, not in this flake.

## Usage

Import and enable the base module explicitly:

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nixos-core.nixosModules.base ];

  nixos-core.base = {
    enable = true;
    username = "andrew";
    enableFlakes = true;
    experimentalFeatures = [ "nix-command" "flakes" ];
    systemPackages = with pkgs; [ git vim ];
  };
}
```

`base.username` is the username source of truth for shared NixOS and
Home-Manager consumers. Host modules should set it once, and shared profiles
should read it rather than hardcoding a user or home directory.

## Modules

| Module | Purpose |
|---|---|
| `nixosModules.base` | Base system tier: user account, Nix, networking, SSH, Tailscale, locale, Docker, nix-ld, and AppImage support. |
| `nixosModules.desktop` | Opt-in graphical system tier. |
| `nixosModules.nvidia-compute` | Opt-in NVIDIA/CUDA compute support. |
| `nixosModules.input-kanata` | Opt-in keyboard remapping support. |
| `nixosModules.cross-compile` | Opt-in cross-compilation support. |
| `nixosModules.wsl-upstream` / `nixosModules.wsl` | Upstream and convenience WSL integration. |

All modules are inert until their own enable option is set.
