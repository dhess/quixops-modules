let
  nixpkgs = (import ./lib.nix).nixpkgs;

in

{ pkgs ? nixpkgs {} }:

with pkgs.lib;
let
  self = foldl'
    (prev: overlay: prev // (overlay (pkgs // self) (pkgs // prev)))
    {} (map import (import ./overlays.nix));
in
self //
{
  # Note: I don't yet provide a NUR-style module attrset, because the
  # modules provided by this repo are quite complicated and
  # interdependent. Furthermore, they're written with the assumption
  # that you're using the overlay provided by the repo, so you'd need
  # to use this repo as an overlay and not as a NUR import, anyway.
  #
  # A future version might refactor things so that they're
  # NUR-compatible.

  overlays.quixops-modules = import ./overlays/lib/quixops-modules.nix;
  overlays.types = import ./overlays/lib/types.nix;
}
