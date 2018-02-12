# This file is useful for testing from the command line, without
# needing to round-trip through Hydra:
#
# nix-build jobsets/release-tests.nix

let

  lib = import ../lib.nix;

in

{ system ? "x86_64-linux"
, supportedSystems ? [ "x86_64-linux" "aarch64-linux" "armv7l-linux" ]
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
