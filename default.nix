# From GitHub: mozilla/nixpkgs-mozilla/default.nix.

self: super:

with super.lib;

let

  localLib = import ./lib.nix;

in
(foldl' (flip extends) (_: super) [

  (import localLib.fetchNixPkgsQuixoftic)
  (import ./overlays/lib.nix)

]) self
