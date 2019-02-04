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
  overlays.quixops-modules = import ./overlays/lib/quixops-modules.nix;
  overlays.types = import ./overlays/lib/types.nix;
}
