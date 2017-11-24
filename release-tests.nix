let

  lib = import ./lib.nix;

in

{ pkgs ? (import (lib.fetchNixPkgs) { system = "x86_64-linux"; })
, supportedSystems ? [ "x86_64-linux" "armv7l-linux" ]
}:

let

in
  lib.collect
    lib.isDerivation
    (import ./release.nix { inherit pkgs supportedSystems; }).tests
