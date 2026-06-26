{
  description = "System-level NixOS modules: base, desktop, headless CUDA, kanata, cross-compile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # No nirinit input — desktop sets only programs.niri.enable; the services.nirinit
    # daemon is deferred to the graphical-tier consumer (nix-meta), keeping the
    # headless tower free of a desktop-only input (nixos-core-PLAN §2.2/§3.2).
    # No CUDA/nvidia input — driver/toolkit/CUDA come straight from nixpkgs; the
    # cuda-maintainers cachix is declared inside the nvidia-compute module.
  };

  outputs = { self, nixpkgs, nixos-wsl, ... }: {
    nixosModules = {
      # ── tower-relevant (the five Wave-1 deliverables) ──
      base = import ./modules/base.nix; # RENAME ← common
      desktop = import ./modules/desktop.nix; # NEW
      nvidia-compute = import ./modules/nvidia-compute.nix; # NEW (greenfield)
      input-kanata = import ./modules/input-kanata; # NEW (dir + verbatim fragments)
      cross-compile = import ./modules/cross-compile.nix; # NEW (greenfield)

      # ── legacy WSL (kept, inert, out of the tower path) ──
      wsl-upstream = nixos-wsl.nixosModules.default;
      wsl = import ./modules/wsl.nix;

      # ── template aggregate ──
      default = import ./modules/default.nix;
    };
  };
}
