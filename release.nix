let

  lib = import ./lib.nix;

in

{ system ? builtins.currentSytem
, pkgs ? (import (lib.fetchNixPkgs) { inherit system; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

in rec {

  tests = import ./tests { inherit pkgs supportedSystems; };

}
