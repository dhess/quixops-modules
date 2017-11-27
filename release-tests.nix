let

  lib = import ./lib.nix;

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
