# Aggregate — imports every local sibling module; each stays behind its own enable
# flag, so importing `default` is inert. (`wsl-upstream` is a re-export of an
# external flake's module, not a local file, so it is NOT listed here.) nix-meta
# imports the modules discretely and never relies on this aggregate.
{
  imports = [
    ./base.nix
    ./desktop.nix
    ./nvidia-compute.nix
    ./input-kanata
    ./cross-compile.nix
    ./wsl.nix
  ];
}
