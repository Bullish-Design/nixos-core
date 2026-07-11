# modules/nvidia-compute.nix — headless compute-only NVIDIA for the tower (dual
# RTX 3060, Ampere GA106, CUDA cap 8.6). GREENFIELD (no .dotfiles source — laptop
# is Intel). Capability `gpuCompute`. The THIN driver+toolkit substrate for vLLM/act
# (which run in devenv-lib); ships zero vLLM package/pin and NO vLLM unit (that is a
# nix-meta tower-host-fragment concern). NO display stack — never sets
# services.xserver.enable, never pulls a compositor (headless means headless).
#
# NOTE: `services.xserver.videoDrivers = [ "nvidia" ]` IS set below and is
# REQUIRED — it is nixpkgs' only supported switch for a consumer GPU to wire the
# driver (the whole `hardware.nvidia` config block is `mkIf hardware.nvidia.enabled`,
# and `.enabled` is read-only, defaulting to true iff "nvidia" ∈ videoDrivers or
# datacenter.enable). Despite the `xserver.` namespace it does NOT start X: X11
# runs only when `services.xserver.enable = true`, which we never set. So this
# stays fully headless while actually installing the driver + nvidia-smi. The
# datacenter path is the wrong alternative here (it's for NVLink DC cards +
# fabricmanager, not RTX 3060 consumer GPUs).
{ config, lib, pkgs, ... }:
let
  cfg = config.nixos-core.nvidia-compute;
  # nvidia-smi ships in the driver's `bin` output, NOT `out` — `${cfg.package}`
  # (the default `out` output) has no bin/nvidia-smi, so referencing it there
  # makes the power-limit oneshot exit 127. Always resolve via lib.getBin.
  nvidiaSmi = "${lib.getBin cfg.package}/bin/nvidia-smi";
in
{
  options.nixos-core.nvidia-compute = {
    enable = lib.mkEnableOption "headless compute-only NVIDIA (CUDA) for the tower";

    package = lib.mkOption {
      type = lib.types.package;
      default = config.boot.kernelPackages.nvidiaPackages.production;
      defaultText = lib.literalExpression "config.boot.kernelPackages.nvidiaPackages.production";
      description = "NVIDIA driver package — production channel.";
    };

    cudaCapabilities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "8.6" ];
      description = "CUDA capability list (Ampere GA106).";
    };

    containerToolkit.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "hardware.nvidia-container-toolkit (lets vLLM/act run in Docker with --gpus).";
    };

    powerLimitWatts = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        If non-null, the oneshot runs `nvidia-smi -pl <watts>` (~120-130 W ≈ 70%).
        null = no-op. Memory clock is left HIGH — never underclocked. The optimal
        value is empirical (tune on-box, Phase 4 — nixos-core-PLAN §10-Q8).
      '';
    };

    persistenceMode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run `nvidia-smi -pm 1` (persistence mode) in the oneshot.";
    };

    minimizeFbconVram = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Best-effort kernel cmdline to keep framebuffer-console VRAM near zero on the
        headless box. The SAFEST exact param for a headless, no-iGPU, NVIDIA-only box
        is empirical — tuned on-box (Phase 4, nixos-core-PLAN §10-Q8). Placeholder
        kept conservative.
      '';
    };

    cachix.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "cuda-maintainers cachix substituter + key (mandatory for CUDA-from-source).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # driver (compute-only): kernel module + KMS, NO compositor path.
      # videoDrivers is the driver-wiring switch (see header) — it does NOT enable
      # X; xserver stays off because services.xserver.enable is never set.
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.nvidia.open = true; # Ampere supports the open kernel module
      hardware.nvidia.package = cfg.package;
      hardware.nvidia.modesetting.enable = true;

      # CUDA userspace (provides the libs CUDA needs even headless).
      hardware.graphics.enable = true;
      nixpkgs.config.cudaSupport = true;
      nixpkgs.config.cudaCapabilities = cfg.cudaCapabilities;

      # container toolkit (Docker daemon itself comes from base).
      hardware.nvidia-container-toolkit.enable = cfg.containerToolkit.enable;

      # tooling: nvidia-smi (the driver's `bin` output) on PATH.
      environment.systemPackages = [ (lib.getBin cfg.package) ];

      # power-limit + persistence oneshot — declarative, survives reboot via
      # RemainAfterExit + wantedBy multi-user.target; no-op when both off.
      systemd.services.nvidia-power-limit = {
        wantedBy = [ "multi-user.target" ];
        after = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = lib.concatStringsSep "\n" (
          (lib.optional cfg.persistenceMode "${nvidiaSmi} -pm 1")
          ++ (lib.optional (cfg.powerLimitWatts != null)
            "${nvidiaSmi} -pl ${toString cfg.powerLimitWatts}")
          ++ [ "true" ] # ensure a non-empty, always-succeeding script when both off
        );
      };
    }

    (lib.mkIf cfg.minimizeFbconVram {
      # TODO (Phase 4, on-box): the safest fbcon-VRAM-minimizing kernel param for a
      # headless, no-iGPU, NVIDIA-only box is empirical — verify on the tower.
      boot.kernelParams = [ "fbcon=nodefer" ];
    })

    (lib.mkIf cfg.cachix.enable {
      nix.settings.extra-substituters = [ "https://cuda-maintainers.cachix.org" ];
      nix.settings.extra-trusted-public-keys = [
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    })
  ]);
}
