# modules/input-kanata/ — kanata keyboard remap. Ports .dotfiles/modules/nixos/
# input/kanata wholesale: the 8 .kbd fragments are BYTE-IDENTICAL; the only change
# from source is wrapping the whole thing in the nixos-core.input-kanata.enable gate
# (source was unconditional). The extraDefCfg + concat order are verbatim.
{ config, lib, ... }:
let
  cfg = config.nixos-core.input-kanata;
  fragments = [
    ./fragments/100-defsrc.kbd
    ./fragments/200-base.kbd
    ./fragments/250-homerow-mods.kbd
    ./fragments/300-nav.kbd
    ./fragments/350-sidebar.kbd
    ./fragments/400-resize.kbd
    # Stale for now: no key currently enters the leader layer.
    # Remove this fragment once leader experiments are fully abandoned.
    ./fragments/500-leader.kbd
    ./fragments/900-safety.kbd
  ];
  finalKbd = lib.concatStringsSep "\n\n" (map builtins.readFile fragments);
in
{
  options.nixos-core.input-kanata.enable =
    lib.mkEnableOption "kanata keyboard remap (verbatim .dotfiles fragments)";

  config = lib.mkIf cfg.enable {
    services.kanata = {
      enable = true;
      keyboards.main = {
        extraDefCfg = ''
          process-unmapped-keys yes
          concurrent-tap-hold yes
          chords-v2-min-idle 25
        '';
        config = finalKbd;
      };
    };
  };
}
