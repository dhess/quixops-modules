let

  lib = import ../lib.nix;
  fixedNixPkgs = lib.fetchNixPkgs;
  packageSet = (import fixedNixPkgs);

in

{ system ? builtins.currentSystem
, supportedSystems ? [ "x86_64-linux" ]
, scrubJobs ? true
, nixpkgsArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    overlays = [
      (import ../.)
    ];
  }
, modules ? (import ../modules/module-list.nix)
}:

with import (fixedNixPkgs + "/pkgs/top-level/release-lib.nix") {
  inherit supportedSystems scrubJobs nixpkgsArgs;
};

let

  testing = import "${lib.fetchNixPkgs}/nixos/lib/testing.nix" { inherit system; };
  inherit (testing) makeTest;

  importTest = fn: args: system: import fn ({
    inherit system pkgs modules makeTest;
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

  tests = {
    ## Overlays.
    #bb-org-overlays = callSubTests ./bb-org-overlays.nix { system = "armv7l-linux"; };
    custom-cacert = callSubTests ../tests/custom-cacert.nix {};
    ffmpeg-snapshot = callSubTests ../tests/ffmpeg-snapshot.nix {};
    unbound-block-hosts = callSubTests ../tests/unbound-block-hosts.nix {};
    suricata = callTest ../tests/suricata.nix { system = "x86_64-linux"; };
    trimpcap = callTest ../tests/trimpcap.nix {};
    tsoff = callSubTests ../tests/tsoff.nix {};

    ## Modules.
    hydra-manual-setup = callTest ../tests/hydra-manual-setup.nix { system = "x86_64-linux"; };
    netsniff-ng = callSubTests ../tests/netsniff-ng.nix {};
    znc = callSubTests ../tests/znc.nix {};

    ## Configuration.

    environment = callSubTests ../tests/environment.nix {};
    networking = callSubTests ../tests/networking.nix {};
    security = callSubTests ../tests/security.nix {};
    sudo = callSubTests ../tests/sudo.nix {};
    ssh = callSubTests ../tests/ssh.nix {};
    system = callSubTests ../tests/system.nix {};
    users = callSubTests ../tests/users.nix {};
  };

in rec {

  inherit tests;

}
