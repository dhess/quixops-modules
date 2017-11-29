let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import (lib.fetchNixPkgs) { inherit system; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

  forAllSystems = lib.genAttrs supportedSystems;
  callTest = lib.callTest forAllSystems;
  callSubTests = lib.callSubTests supportedSystems;

in rec {

  ## Overlays.
  #bb-org-overlays = callSubTests ./bb-org-overlays.nix { system = "armv7l-linux"; };
  unbound-block-hosts = callSubTests ./unbound-block-hosts.nix {};

  ## Configuration.

  environment = callSubTests ./environment.nix {};
  networking = callSubTests ./networking.nix {};
  security = callSubTests ./security.nix {};
  sudo = callSubTests ./sudo.nix {};
  ssh = callSubTests ./ssh.nix {};
  system = callSubTests ./system.nix {};
  users = callSubTests ./users.nix {};

}
