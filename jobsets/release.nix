let

  lib = import ../lib.nix;
  fixedNixPkgs = lib.fetchNixPkgs;
  packageSet = (import fixedNixPkgs);

in

{ system ? "x86_64-linux"
, supportedSystems ? [ "x86_64-linux" ]
, scrubJobs ? true
, nixpkgsArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    overlays = [
      (import ../.)
    ];
  }
}:

with import (fixedNixPkgs + "/pkgs/top-level/release-lib.nix") {
  inherit supportedSystems scrubJobs nixpkgsArgs packageSet;
};

let

  testing = import (fixedNixPkgs + "/nixos/lib/testing.nix") { inherit system; };
  inherit (testing) makeTest;

  importTest = fn: args: system: import fn ({
    inherit system pkgs makeTest;
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
    unbound-block-hosts = callSubTests ../tests/unbound-block-hosts.nix {};
    suricata = callTest ../tests/suricata.nix { system = "x86_64-linux"; };
    trimpcap = callTest ../tests/trimpcap.nix {};
    tsoff = callSubTests ../tests/tsoff.nix {};

    ## Modules.
    allowed-ips = callSubTests ../tests/allowed-ips.nix {};
    anycast = callTest ../tests/anycast.nix {};
    hydra-manual-setup = callTest ../tests/hydra-manual-setup.nix { system = "x86_64-linux"; };
    full-tunnel-vpn = callSubTests ../tests/full-tunnel-vpn.nix {};
    mellon-auto-unlock = callTest ../tests/mellon-auto-unlock.nix {};
    netsniff-ng = callSubTests ../tests/netsniff-ng.nix {};
    pinpon = callTest ../tests/pinpon.nix {};
    postfix-null-client = callTest ../tests/postfix-null-client.nix {};
    postfix-relay-host = callTest ../tests/postfix-relay-host.nix {};
    service-status-email = callTest ../tests/service-status-email.nix {};
    tarsnapper = callTest ../tests/tarsnapper.nix {};
    unbound-anycast = callTest ../tests/unbound-anycast.nix {};
    znc = callSubTests ../tests/znc.nix {};

    ## Configuration.

    environment = callSubTests ../tests/environment.nix {};
    fail2ban = callTest ../tests/fail2ban.nix {};
    hwutils = callTest ../tests/hwutils.nix {};
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
