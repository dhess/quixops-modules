{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

  # Don't do this in production -- it will put the secrets into the
  # Nix store! This is just a convenience for the tests.

  ca-cert = pkgs.copyPathToStore ./testfiles/certs/root.crt;
  crl = pkgs.copyPathToStore ./testfiles/crls/acme.com.crl;

  vpn1-cert = pkgs.copyPathToStore ./testfiles/certs/vpn1.acme.com.crt;
  vpn1-certKey = pkgs.copyPathToStore ./testfiles/keys/vpn1.acme.com.key;
  vpn1-tlsAuthKey = pkgs.copyPathToStore ./testfiles/keys/vpn1.acme.com-tls-auth.key;
  vpn2-cert = pkgs.copyPathToStore ./testfiles/certs/vpn2.acme.com.crt;
  vpn2-certKey = pkgs.copyPathToStore ./testfiles/keys/vpn2.acme.com.key;
  vpn2-tlsAuthKey = pkgs.copyPathToStore ./testfiles/keys/vpn2.acme.com-tls-auth.key;

  bob-cert = pkgs.copyPathToStore ./testfiles/certs/bob-at-acme.com.crt;
  bob-certKey = pkgs.copyPathToStore ./testfiles/keys/bob-at-acme.com.key;
  alice-cert = pkgs.copyPathToStore ./testfiles/certs/alice-at-acme.com.crt;
  alice-certKey = pkgs.copyPathToStore ./testfiles/keys/alice-at-acme.com.key;

in makeTest rec {
  name = "openvpn-full";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {
    client = { config, ... }: {
      nixpkgs.system = system;
    };

    server = { config, ... }: {
      nixpkgs.system = system;
      imports = (import pkgs.lib.quixops.modulesPath);
      services.openvpn-full = {
        routedInterface = "eth1";
        servers = {
          vpn1 = {
            ipv4ClientBaseAddr = "10.0.0.0";
            ipv6ClientPrefix = "fd00:1234:5678:9::/64";
            caFile = ca-cert;
            certFile = vpn1-cert;
            certKeyFile = vpn1-certKey;
            crlFile = crl;
            tlsAuthKey = vpn1-tlsAuthKey;
            # Don't do this at home -- just for faster testing
            dhparamsSize = 128;
          };
          vpn2 = {
            port = 443;
            proto = "tcp";
            ipv4ClientBaseAddr = "10.0.1.0";
            ipv6ClientPrefix = "fd00:1234:5678:a::/64";
            caFile = ca-cert;
            certFile = vpn2-cert;
            certKeyFile = vpn2-certKey;
            crlFile = crl;
            tlsAuthKey = vpn2-tlsAuthKey;
            # Don't do this at home -- just for faster testing
            dhparamsSize = 128;
          };
        };
      };
    };
  };

  testScript = { nodes, ... }:
  let
  in ''
    startAll;

    $client->waitForUnit("multi-user.target");
    $server->waitForUnit("openvpn-vpn1.service");
    $server->waitForUnit("openvpn-vpn2.service");
  '';
}
