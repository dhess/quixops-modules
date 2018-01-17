# This file is useful for testing from the command line, without
# needing to round-trip through Hydra:
#
# nix-build jobsets/release-tests.nix

let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import (lib.fetchNixPkgs) { inherit system; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

in
  lib.collect
    lib.isDerivation
    (import ./release.nix { inherit pkgs supportedSystems; }).tests
