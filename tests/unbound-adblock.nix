{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:


let

  hostsfile = pkgs.writeText "hostsfile" ''
    #<localhost>
    127.0.0.1	localhost
    127.0.0.1	localhost.localdomain
    255.255.255.255	broadcasthost
    ::1		localhost
    127.0.0.1	local
    #fe80::1%lo0	localhost
    #</localhost>
    #<doubleclick-sites>
    127.0.0.1 doubleclick.com
    127.0.0.1 doubleclick.de
    127.0.0.1 doubleclick.net        
  '';

  ipv6_prefix = "fd00:1234:5678::/64";

  serverIpv4_1 = "192.168.1.251";
  serverIpv4_2 = "192.168.1.252";
  serverIpv6_1 = "fd00:1234:5678::1";
  serverIpv6_2 = "fd00:1234:5678::2";

in makeTest rec {

  name = "unbound-adblock";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {

    server = { config, ... }: {
      nixpkgs.system = system;
      nixpkgs.overlays = [ (import ../.) ];
      imports = (import pkgs.lib.quixops.modulesPath);
      services.unbound-adblock = {
        enable = true;
        allowedAccessIpv4 = [ "192.168.1.0/24" ];
        allowedAccessIpv6 = [ ipv6_prefix ];
        virtualServiceIpv4s = [ serverIpv4_1 serverIpv4_2 ];
        virtualServiceIpv6s = [ serverIpv6_1 serverIpv6_2 ];
      };
      networking.interfaces.eth1.ip6 = [
        { address = "fd00:1234:5678::1000"; prefixLength = 64; }
      ];
    };

    client = { config, ... }: {
      nixpkgs.system = system;
      networking.interfaces.eth1.ip6 = [
        { address = "fd00:1234:5678::2000"; prefixLength = 64; }
      ];
    }; 

  };

  testScript = { nodes, ... }:
  ''
    startAll;

    $server->waitForUnit("unbound.service");
    $client->waitForUnit("multi-user.target");

    # Make sure we have IPv6 connectivity and there isn't an issue
    # with the network setup in the test.
    
    $server->succeed("ping -c 1 fd00:1234:5678::2000 >&2");
    $client->succeed("ping -c 1 fd00:1234:5678::1000 >&2");
    #$client->succeed("ping -c 1 ${serverIpv6_1} >&2");
    #$client->succeed("ping -c 1 ${serverIpv6_2} >&2");

    sub testDoubleclick {
      my ($machine, $dnsip, $extraArg) = @_;
      my $ipv4 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg A doubleclick.com +short");
      $ipv4 =~ /^127\.0\.0\.1$/ or die "doubleclick.com does not resolve to 127.0.0.1";
      my $ipv6 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg AAAA doubleclick.com +short");
      $ipv6 =~ /^::1$/ or die "doubleclick.com does not resolve to ::1";
    }

    subtest "adblock", sub {
      testDoubleclick $client, "${serverIpv4_1}", "";
      testDoubleclick $client, "${serverIpv4_2}", "";
      #testDoubleclick $client, "${serverIpv6_1}", "-6";
      #testDoubleclick $client, "${serverIpv6_2}", "-6";
    };

  '';
}
