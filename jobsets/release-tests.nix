# This file is useful for testing from the command line, without
# needing to round-trip through Hydra:
#
# nix-build jobsets/release-tests.nix

let

  lib = import ../lib.nix;
  fixedNixPkgs = lib.fetchNixPkgs;
  packageSet = (import fixedNixPkgs);

in

{ system ? builtins.currentSystem
, supportedSystems ? [ "x86_64-linux" ]
, scrubJobs ? true
, nixpkgsArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    overlays = [
      (import ../.)
    ];
  }
}:

let

in
  lib.collect
    lib.isDerivation
    (import ./release.nix { inherit system supportedSystems scrubJobs nixpkgsArgs; }).tests
