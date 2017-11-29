# From GitHub: mozilla/nixpkgs-mozilla/default.nix.

self: super:

with super.lib;

(foldl' (flip extends) (_: super) [

  (import ./custom-packages.nix)
  (import ./disable-tests.nix)
  (import ./functions.nix)
  (import ./haskell.nix)

]) self
