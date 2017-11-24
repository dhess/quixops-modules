let

  lib = import ../lib.nix;

in

{ pkgs ? (import (lib.fetchNixPkgs) { system = "x86_64-linux"; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

  forAllSystems = lib.genAttrs supportedSystems;
  callTest = lib.callTest forAllSystems;
  callSubTests = lib.callSubTests supportedSystems;

in rec {

  environment = callSubTests ./environment.nix {};
  ssh = callTest ./ssh.nix {};

}
