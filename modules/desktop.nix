# modules/desktop.nix — the SYSTEM half of the graphical tier. Pairs with the
# nix-desktop HM repo (which owns niri config.kdl + shell settings). Owns
# DM/session/seat/audio/fonts/cursor/wl-utils + programs.niri.enable +
# bluetooth/upower/power + the niri/noctalia cachix. Ports the display/audio/xkb
# lines of .dotfiles/configuration.nix + desktop/{niri-session,noctalia-support}.nix.
#
# NOTE: services.nirinit is deliberately NOT enabled here (no nirinit input — keeps
# the headless tower free of a desktop-only input). The graphical-tier consumer
# (nix-meta / framework host fragment) carries inputs.nirinit + services.nirinit if
# session-restore is wanted (nixos-core-PLAN §3.2 / §10-Q3, GAP-C).
#
# `programs.niri.enable` is provided by the niri flake's NixOS module, which nixos-core
# does NOT import — nix-meta composes it alongside this module on the graphical tier.
# So this module only evaluates standalone with niri.enable = false.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixos-core.desktop;
in
{
  options.nixos-core.desktop = {
    enable = lib.mkEnableOption "the graphical system tier (DM/session/audio/fonts + niri)";

    niri.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "programs.niri.enable + GDM defaultSession = niri.";
    };
    gnome.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "services.desktopManager.gnome.enable (default off; source had it on).";
    };
    audio.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "PipeWire audio stack (pulseaudio off + rtkit + pipewire).";
    };
    bluetooth.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "hardware.bluetooth.enable.";
    };
    power.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "upower + power-profiles-daemon (laptop-only conveniences).";
    };
    printing.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "CUPS printing.";
    };
    cachix.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "niri + noctalia cachix substituters + trusted keys (system-side, nix-meta-PLAN §9).";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # session / display manager
      services.xserver.enable = true;
      services.displayManager.gdm.enable = true;
      services.displayManager.defaultSession = lib.mkIf cfg.niri.enable "niri";
      programs.niri.enable = lib.mkIf cfg.niri.enable true;
      services.desktopManager.gnome.enable = cfg.gnome.enable;

      # xkb / console
      services.xserver.xkb = {
        layout = "us";
        variant = "";
        options = "";
      };
      console.useXkbConfig = true;

      # hardware support
      hardware.bluetooth.enable = cfg.bluetooth.enable;
      services.upower.enable = cfg.power.enable;
      services.power-profiles-daemon.enable = cfg.power.enable;
      services.printing.enable = cfg.printing.enable;

      # graphical-tier coverage: fonts + wayland utils concentrated system-side
      # (greenfield — .dotfiles scatters some in HM; audit during nix-desktop build
      # to avoid double-providing — GAP-B / §10-Q7).
      fonts.packages = with pkgs; [
        noto-fonts
        noto-fonts-color-emoji
        liberation_ttf
        nerd-fonts.jetbrains-mono
      ];
      environment.systemPackages = with pkgs; [
        wl-clipboard
        wtype
        grim
        slurp
        brightnessctl
      ];
    }

    (lib.mkIf cfg.audio.enable {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };
    })

    (lib.mkIf cfg.cachix.enable {
      # Keys lifted verbatim from .dotfiles/flake.nix nixConfig. Additive so the
      # default cache.nixos.org substituter is preserved.
      nix.settings.extra-substituters = [
        "https://niri.cachix.org"
        "https://noctalia.cachix.org"
      ];
      nix.settings.extra-trusted-public-keys = [
        "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
        "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      ];
    })
  ]);
}
