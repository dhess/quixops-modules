let

  lib = import ./lib.nix;

in

{ pkgs ? (import (lib.fetchNixPkgs) { system = "x86_64-linux"; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

in rec {

  tests = import ./tests { inherit pkgs supportedSystems; };

}
