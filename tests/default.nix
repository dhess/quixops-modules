let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import (lib.fetchNixPkgs) { inherit system; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

  ## Test harness.
  #

  testing = import "${lib.fetchNixPkgs}/nixos/lib/testing.nix" { inherit system; };
  inherit (testing) makeTest;

  forAllSystems = lib.genAttrs supportedSystems;

  importTest = fn: args: system: import fn ({
    inherit system makeTest;
  } // args);

  callTest = fn: args: forAllSystems (system: lib.hydraJob (importTest fn args system));

  callSubTests = fn: args: let
    discover = attrs: let
      subTests = lib.filterAttrs (lib.const (lib.hasAttr "test")) attrs;
    in lib.mapAttrs (lib.const (t: lib.hydraJob t.test)) subTests;

    discoverForSystem = system: lib.mapAttrs (_: test: {
      ${system} = test;
    }) (discover (importTest fn args system));

  # If the test is only for a particular system, use only the specified
  # system instead of generating attributes for all available systems.
  in if args ? system then discover (import fn args)
     else lib.foldAttrs lib.mergeAttrs {} (map discoverForSystem supportedSystems);

in rec {

  ## Overlays.
  #bb-org-overlays = callSubTests ./bb-org-overlays.nix { system = "armv7l-linux"; };
  custom-cacert = callSubTests ./custom-cacert.nix {};
  ffmpeg-snapshot = callSubTests ./ffmpeg-snapshot.nix {};
  unbound-block-hosts = callSubTests ./unbound-block-hosts.nix {};
  suricata = callTest ./suricata.nix { system = "x86_64-linux"; };
  trimpcap = callTest ./trimpcap.nix {};
  tsoff = callSubTests ./tsoff.nix {};

  ## Modules.
  hydra-manual-setup = callTest ./hydra-manual-setup.nix { system = "x86_64-linux"; };
  netsniff-ng = callSubTests ./netsniff-ng.nix {};
  znc = callSubTests ./znc.nix {};

  ## Configuration.

  environment = callSubTests ./environment.nix {};
  networking = callSubTests ./networking.nix {};
  security = callSubTests ./security.nix {};
  sudo = callSubTests ./sudo.nix {};
  ssh = callSubTests ./ssh.nix {};
  system = callSubTests ./system.nix {};
  users = callSubTests ./users.nix {};

}
