{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:


let

  index = pkgs.writeText "index.html" ''
    Not really HTML.
  '';

  makeAllowedIPsTest = name: makeTest rec {

    inherit name;

    meta = with pkgs.lib.maintainers; {
      maintainers = [ dhess-qx ];
    };

    nodes = {

      server = { config, ... }: {
        nixpkgs.localSystem.system = system;
        imports = (import pkgs.lib.quixops.modulesPath);
        networking.useDHCP = false;
        networking.firewall.enable = true;
        networking.firewall.allowedIPs = [
          { protocol = "tcp";
            port = 80;
            v4 = [ "192.168.1.2/32" ];
            v6 = [ "fd00:1234:5678::2000/128" ];
          }
        ];
        services.nginx = {
          enable = true;
          virtualHosts."server" = {
            locations."/".root = pkgs.runCommand "docroot" {} ''
              mkdir -p "$out/"
              cp "${index}" "$out/index.html"
            '';
          };
        };
        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.1.1"; prefixLength = 24; }
        ];
        networking.interfaces.eth1.ipv6.addresses = [
          { address = "fd00:1234:5678::1000"; prefixLength = 64; }
        ];
      };

      client = { config, ... }: {
        nixpkgs.localSystem.system = system;
        networking.useDHCP = false;
        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.1.2"; prefixLength = 24; }
        ];
        networking.interfaces.eth1.ipv6.addresses = [
          { address = "fd00:1234:5678::2000"; prefixLength = 64; }
        ];
      };

      badclient = { config, ... }: {
        nixpkgs.localSystem.system = system;
        networking.useDHCP = false;
        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.1.3"; prefixLength = 24; }
        ];
        networking.interfaces.eth1.ipv6.addresses = [
          { address = "fd00:1234:5678::3000"; prefixLength = 64; }
        ];
      };

    };

    testScript = { nodes, ... }:
    ''
      startAll;

      $server->waitForUnit("nginx.service");
      $client->waitForUnit("multi-user.target");
      $badclient->waitForUnit("multi-user.target");

      # Make sure we have IPv6 connectivity and there isn't an issue
      # with the network setup in the test.

      sub waitForAddress {
          my ($machine, $iface, $scope) = @_;
          $machine->waitUntilSucceeds("[ `ip -o -6 addr show dev $iface scope $scope | grep -v tentative | wc -l` -eq 1 ]");
          my $ip = (split /[ \/]+/, $machine->succeed("ip -o -6 addr show dev $iface scope $scope"))[3];
          $machine->log("$scope address on $iface is $ip");
          return $ip;
      }

      waitForAddress $client, "eth1", "global";
      waitForAddress $badclient, "eth1", "global";
      waitForAddress $server, "eth1", "global";

      $server->succeed("ping -c 1 fd00:1234:5678::2000 >&2");
      $server->succeed("ping -c 1 fd00:1234:5678::3000 >&2");
      $client->succeed("ping -c 1 fd00:1234:5678::1000 >&2");
      $badclient->succeed("ping -c 1 fd00:1234:5678::1000 >&2");

      # Make sure nginx is running.
      subtest "localhost-connections", sub {
        $server->succeed("${pkgs.netcat}/bin/nc -w 5 localhost 80");
      };

      subtest "allow-remote-connections", sub {
        $client->succeed("${pkgs.netcat}/bin/nc -w 5 server 80");
      };

      subtest "no-remote-connections", sub {
        $badclient->fail("${pkgs.netcat}/bin/nc -w 5 server 80");
      };

    '';
  };

in
{
  allowedIPs = makeAllowedIPsTest "allowed-ips";
}
