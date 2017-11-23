let

  lib = import ./lib.nix;

in

{ pkgs ? (import (lib.fetchNixPkgs) { system = "x86_64-linux"; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

in
  lib.mapAttrsToList
    (n: v: v.x86_64-linux or {})
    (import ./release.nix { inherit pkgs supportedSystems; }).tests
