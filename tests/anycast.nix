{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

  ipv6_prefix = "fd00:1234:5678::/64";

  serverIpv4_1 = "192.168.1.98";
  serverIpv4_2 = "192.168.1.99";
  serverIpv6_1 = "fd00:1234:5678::1";
  serverIpv6_2 = "fd00:1234:5678::2";

in

makeTest {
  name = "anycast";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {

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

    server = { config, ... }: {
      nixpkgs.localSystem.system = system;
      imports = (import pkgs.lib.quixops.modulesPath);
      networking.interfaces.eth1.ipv4.addresses = [
        { address = "192.168.1.1"; prefixLength = 24; }
      ];
      networking.interfaces.eth1.ipv6.addresses = [
        { address = "fd00:1234:5678::1000"; prefixLength = 64; }
      ];

      networking.anycastAddrs.v4 = [
        { ifnum = 0; addrOpts = { address = serverIpv4_1; prefixLength = 32; }; }        
        { ifnum = 0; addrOpts = { address = serverIpv4_2; prefixLength = 32; }; }        
      ];
      networking.anycastAddrs.v6 = [
        { ifnum = 0; addrOpts = { address = serverIpv6_1; prefixLength = 32; }; }        
        { ifnum = 0; addrOpts = { address = serverIpv6_2; prefixLength = 32; }; }        
      ];
    };

  };

  testScript = { nodes, ... }:
  let
  in ''
    startAll;

    $client->waitForUnit("multi-user.target");
    $server->waitForUnit("multi-user.target");

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
    waitForAddress $server, "eth1", "global";

    $server->succeed("ping -c 1 fd00:1234:5678::2000 >&2");
    $client->succeed("ping -c 1 fd00:1234:5678::1000 >&2");

    sub testDummyAddrs {
      my $dummyv4 = $server->succeed("ip -o -4 addr show dev dummy0");
      $dummyv4 =~ /"${serverIpv4_1}"/ or die "dummy0 does not have expected IP address ${serverIpv4_1}";
      $dummyv4 =~ /"${serverIpv4_2}"/ or die "dummy0 does not have expected IP address ${serverIpv4_2}";
      my $dummyv6 = $server->succeed("ip -o -6 addr show dev dummy0");
      $dummyv6 =~ /"${serverIpv6_1}"/ or die "dummy0 does not have expected IP address ${serverIpv6_1}";
      $dummyv6 =~ /"${serverIpv6_2}"/ or die "dummy0 does not have expected IP address ${serverIpv6_2}";
    };

    sub testLocalPing {
      $server->succeed("ping -4 -c 1 ${serverIpv4_1} >&2");
      $server->succeed("ping -4 -c 1 ${serverIpv4_2} >&2");
      $server->succeed("ping -c 1 ${serverIpv6_1} >&2");
      $server->succeed("ping -c 1 ${serverIpv6_2} >&2");
    };

    sub testRemotePing {
      $client->succeed("ping -4 -c 1 ${serverIpv4_1} >&2");
      $client->succeed("ping -4 -c 1 ${serverIpv4_2} >&2");
      $client->succeed("ping -c 1 ${serverIpv6_1} >&2");
      $client->succeed("ping -c 1 ${serverIpv6_2} >&2");
    };

  '';
}
