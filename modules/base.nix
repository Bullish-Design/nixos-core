# modules/base.nix — the nixos-core base system layer (RENAME ← common).
# Always applied by nix-meta's `base` tier (Axis 1 rung 0). Ports the
# non-desktop / non-hardware lines of .dotfiles/configuration.nix that every
# host needs: nix settings, the user account + username SSOT, networking,
# ssh/tailscale, shell, locale, the docker daemon, nix-ld/appimage.
{ config, lib, pkgs, ... }:
let
  cfg = config.nixos-core.base;
in
{
  options.nixos-core.base = {
    enable = lib.mkEnableOption "the nixos-core base system layer";

    username = lib.mkOption {
      type = lib.types.str;
      default = "andrew";
      description = ''
        Username SSOT. Every user/service reference reads this. nix-meta threads
        its global meta.username INTO nixos-core.base.username (one value, two views).
      '';
    };

    enableFlakes = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable nix-command + flakes (carried from the old `common`).";
    };

    experimentalFeatures = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nix-command" "flakes" ];
      description = "Nix experimental features (applied when enableFlakes).";
    };

    systemPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra base system packages installed globally.";
    };

    hostName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        If non-null, set networking.hostName. nix-meta normally owns the hostname
        via mkHost, so the default is null (don't touch).
      '';
    };

    tailscale.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable services.tailscale.";
    };

    tailscale.authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        If non-null → services.tailscale.authKeyFile. nix-meta wires this from
        config.sops.secrets."tailscale-auth-key".path (nix-secrets contract).
      '';
    };

    allowUnfree = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "nixpkgs.config.allowUnfree.";
    };

    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "America/New_York";
      description = "time.timeZone.";
    };

    defaultLocale = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "i18n.defaultLocale (+ the LC_* extraLocaleSettings block).";
    };
  };

  config = lib.mkIf cfg.enable {
    # nix
    nix.settings.experimental-features = lib.mkIf cfg.enableFlakes cfg.experimentalFeatures;
    nix.settings.trusted-users = [ cfg.username ];
    nix.optimise.automatic = true;
    nixpkgs.config.allowUnfree = cfg.allowUnfree;

    # user account (the *system* account; nix-meta wires home-manager.users.<name>).
    # adbusers group + the firefox user-package are intentionally dropped (adb is
    # disabled in source; firefox is a nix-apps HM concern, not a system account pkg).
    users.users.${cfg.username} = {
      isNormalUser = true;
      description = "Andrew";
      extraGroups = [ "networkmanager" "wheel" "docker" ];
      shell = pkgs.zsh;
    };
    users.defaultUserShell = pkgs.zsh;
    programs.zsh.enable = true;

    # networking
    networking.networkmanager.enable = true;
    networking.enableIPv6 = true;
    networking.hostName = lib.mkIf (cfg.hostName != null) cfg.hostName;

    # ssh (key-only hardening — greenfield, PLAN §3) + tailscale
    services.openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
      settings.KbdInteractiveAuthentication = false;
    };
    services.tailscale.enable = cfg.tailscale.enable;
    services.tailscale.authKeyFile =
      lib.mkIf (cfg.tailscale.authKeyFile != null) cfg.tailscale.authKeyFile;

    # locale / time
    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = cfg.defaultLocale;
    i18n.extraLocaleSettings = {
      LC_ADDRESS = cfg.defaultLocale;
      LC_IDENTIFICATION = cfg.defaultLocale;
      LC_MEASUREMENT = cfg.defaultLocale;
      LC_MONETARY = cfg.defaultLocale;
      LC_NAME = cfg.defaultLocale;
      LC_NUMERIC = cfg.defaultLocale;
      LC_PAPER = cfg.defaultLocale;
      LC_TELEPHONE = cfg.defaultLocale;
      LC_TIME = cfg.defaultLocale;
    };

    # docker daemon (base — every host gets it; nvidia-compute layers the
    # container *toolkit* on top). PLAN §3.1 / nixos-core-PLAN §10-Q4.
    virtualisation.docker.enable = true;

    # host-agnostic conveniences (nixos-core-PLAN §10-Q5: nix-ld + appimage in
    # base; the bootloader lives in nix-meta's hardware/<host>.nix, generated per box).
    programs.nix-ld.enable = true;
    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    environment.systemPackages = cfg.systemPackages;
  };
}
