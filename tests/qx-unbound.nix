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
    127.0.0.1 ads.doubleclick.com
    127.0.0.1 ads.doubleclick.de
    127.0.0.1 ads.doubleclick.net
  '';

  ipv6_prefix = "fd00:1234:5678::/64";

  serverIpv4_1 = "192.168.1.251";
  serverIpv4_2 = "192.168.1.252";
  serverIpv6_1 = "fd00:1234:5678::1";
  serverIpv6_2 = "fd00:1234:5678::2";

  makeUnboundTest = name: blockListEnable: makeTest rec {

    inherit name;

    meta = with pkgs.lib.maintainers; {
      maintainers = [ dhess-qx ];
    };

    nodes = {

      nsd = { config, ... }: {
        nixpkgs.localSystem.system = system;
        networking.interfaces.eth1.ipv4.addresses = [
          { address = "192.168.1.250"; prefixLength = 24; }
        ];
        networking.interfaces.eth1.ipv6.addresses = [
          { address = "fd00:1234:5678::ffff"; prefixLength = 64; }
        ];
        networking.firewall.allowedUDPPorts = [ 53 ];
        services.nsd.enable = true;
        services.nsd.interfaces = [ "192.168.1.250" ];
        services.nsd.zones."example.com.".data = ''
          @ SOA ns.example.com noc.example.com 666 7200 3600 1209600 3600
          ipv4 A 1.2.3.4
          ipv6 AAAA abcd::eeff
        '';
        services.nsd.zones."doubleclick.com.".data = ''
          @ SOA ns.doubleclick.com noc.doubleclick.com 666 7200 3600 1209600 3600
          ads A 13.13.13.13
          ads AAAA dead::beef
        '';
      };

      server = { config, ... }: {
        nixpkgs.localSystem.system = system;
        imports = (import pkgs.lib.quixops.modulesPath);
        networking.useDHCP = false;
        services.qx-unbound = {
          enable = true;
          enableRootTrustAnchor = false; # required for testing.
          blockList.enable = blockListEnable;
          allowedAccessIpv4 = [ "192.168.1.2/32" ];
          allowedAccessIpv6 = [ ipv6_prefix ];
          virtualServiceIpv4s = [ serverIpv4_1 serverIpv4_2 ];
          virtualServiceIpv6s = [ serverIpv6_1 serverIpv6_2 ];
          forwardAddresses = [ "192.168.1.250" ];
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
    let
      blocklist = nodes.server.config.services.qx-unbound.blockList.enable;
    in
    ''
      startAll;

      $server->waitForUnit("qx-unbound.service");
      $nsd->waitForUnit("nsd.service");
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
      waitForAddress $nsd, "eth1", "global";

      $server->succeed("ping -c 1 fd00:1234:5678::2000 >&2");
      $server->succeed("ping -c 1 fd00:1234:5678::3000 >&2");
      $server->succeed("ping -c 1 fd00:1234:5678::ffff >&2");
      $client->succeed("ping -c 1 fd00:1234:5678::1000 >&2");
      $badclient->succeed("ping -c 1 fd00:1234:5678::1000 >&2");
      #$client->succeed("ping -c 1 ${serverIpv6_1} >&2");
      #$client->succeed("ping -c 1 ${serverIpv6_2} >&2");

      sub testDoubleclickBlocked {
        my ($machine, $dnsip, $extraArg) = @_;
        my $ipv4 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg A ads.doubleclick.com +short");
        $ipv4 =~ /^127\.0\.0\.1$/ or die "ads.doubleclick.com does not resolve to 127.0.0.1";
        my $ipv6 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg AAAA ads.doubleclick.com +short");
        $ipv6 =~ /^::1$/ or die "ads.doubleclick.com does not resolve to ::1";
      }

      sub testDoubleclick {
        my ($machine, $dnsip, $extraArg) = @_;
        my $ipv4 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg A ads.doubleclick.com +short");
        $ipv4 =~ /^13\.13\.13\.13$/ or die "ads.doubleclick.com does not resolve to 13.13.13.13";
        my $ipv6 = $machine->succeed("${pkgs.dnsutils}/bin/dig \@$dnsip $extraArg AAAA ads.doubleclick.com +short");
        $ipv6 =~ /^dead::beef$/ or die "ads.doubleclick.com does not resolve to dead::beef";
      }

      subtest "doubleclick", sub {
        if ("${toString blocklist}" eq "true") {
          testDoubleclickBlocked $client, "${serverIpv4_1}", "";
          testDoubleclickBlocked $client, "${serverIpv4_2}", "";
          #testDoubleclickBlocked $client, "${serverIpv6_1}", "-6";
          #testDoubleclickBlocked $client, "${serverIpv6_2}", "-6";
        } else {
          testDoubleclick $client, "${serverIpv4_1}", "";
          testDoubleclick $client, "${serverIpv4_2}", "";
          #testDoubleclick $client, "${serverIpv6_1}", "-6";
          #testDoubleclick $client, "${serverIpv6_2}", "-6";
        }
      };

      subtest "forwarding", sub {
        my $ip = $client->succeed("${pkgs.dnsutils}/bin/dig \@${serverIpv4_1} A ipv4.example.com +short");
        $ip =~ /^1\.2\.3\.4$/ or die "ipv4.example.com does not resolve to 1.2.3.4";
      };

      subtest "badclient", sub {
        $badclient->fail("${pkgs.dnsutils}/bin/dig \@${serverIpv4_1} A ads.doubleclick.com +time=2");
        $badclient->fail("${pkgs.dnsutils}/bin/dig \@${serverIpv4_2} A ads.doubleclick.com +time=2");
        #$badclient->fail("${pkgs.dnsutils}/bin/dig \@${serverIpv6_1} A ads.doubleclick.com +time=2");
        #$badclient->fail("${pkgs.dnsutils}/bin/dig \@${serverIpv6_2} A ads.doubleclick.com +time=2");
      };

      subtest "check-permissions", sub {
        if ("${toString blocklist}" eq "true") {
          $server->succeed("stat -c %a /var/lib/unbound/blocklists/blocklist-someonewhocares.conf | grep 644");
        }
      };

    '';
  };

in
{
  unboundBlockList = makeUnboundTest "qx-unbound-blocklist-enabled" true;
  unboundNoBlockList = makeUnboundTest "qx-unbound-blocklist-disabled" false;
}
