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
  networking = callSubTests ./networking.nix {};
  security = callSubTests ./security.nix {};
  sudo = callSubTests ./sudo.nix {};
  ssh = callSubTests ./ssh.nix {};
  system = callSubTests ./system.nix {};
  users = callSubTests ./users.nix {};

}
