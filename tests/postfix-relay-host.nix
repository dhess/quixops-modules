{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

  # Don't do this in production -- it will put the secrets into the
  # Nix store! This is just a convenience for the tests.

  ca-cert = ./testfiles/certs/root.crt;
  bob-cert = ./testfiles/certs/bob-at-acme.com.crt;
  bob-certKey = ./testfiles/keys/bob-at-acme.com.key;
  bob-certKeyInStore = pkgs.copyPathToStore ./testfiles/keys/bob-at-acme.com.key;

in makeTest rec {
  name = "postfix-relay-host";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {
    host = { config, ... }: {
      nixpkgs.localSystem.system = system;
      imports =
        (import pkgs.lib.quixops.modulesPath) ++
        (import pkgs.lib.quixops.testModulesPath);

       networking.useDHCP = false;
       networking.interfaces.eth1.ipv4.addresses = [
         { address = "192.168.1.1"; prefixLength = 24; }
       ];
       networking.interfaces.eth1.ipv6.addresses = [
         { address = "fd00:1234:5678::1000"; prefixLength = 64; }
       ];

      # Use the test key deployment system.
      deployment.reallyReallyEnable = true;

      services.postfix-relay-host = {
        enable = true;
        myDomain = "example.com";
        myOrigin = "example.com";
        relayDomains = [ "example.com" ];
        anycastAddrs.v4 = [
          { ifnum = 0; addrOpts = { address = "192.168.1.25"; prefixLength = 32; }; }
        ];
        anycastAddrs.v6 = [
          { ifnum = 0; addrOpts = { address = "fd00:1234:5678::25"; prefixLength = 128; }; }
        ];
        smtpTlsCAFile = ca-cert;
        smtpTlsCertFile = bob-cert;
        smtpTlsKeyLiteral = builtins.readFile bob-certKey;
      };
    };
  };

  testScript = { nodes, ... }:
  ''
    $host->waitForUnit("multi-user.target");
    $host->requireActiveUnit("postfix.service");

    subtest "check-keys", sub {
      $host->succeed("diff ${bob-certKeyInStore} /var/lib/postfix-relay-host/relay-host.key");
    };
  '';
}
