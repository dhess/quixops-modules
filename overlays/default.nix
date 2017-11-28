# From GitHub: mozilla/nixpkgs-mozilla/default.nix.

self: super:

with super.lib;

(foldl' (flip extends) (_: super) [

  (import ./disable-tests.nix)
  (import ./haskell.nix)

]) self
