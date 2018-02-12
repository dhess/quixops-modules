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

  virtualServiceIpv4 = "192.168.1.251";

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
        inherit virtualServiceIpv4;
      };
    };

    client = { config, ... }: {
      nixpkgs.system = system;
    }; 

  };

  testScript = { nodes, ... }:
  ''
    startAll;
    $server->waitForUnit("unbound.service");
    $client->waitForUnit("multi-user.target");
    my $serverip = $server->succeed("ip addr show");
    $server->log("server ip: " . $serverip);
    my $clientip = $client->succeed("ip addr show");
    $client->log("client ip: " . $clientip);

    subtest "adblock", sub {
      my $ipv4 = $client->succeed("${pkgs.dnsutils}/bin/dig \@${virtualServiceIpv4} A doubleclick.com +short");
      $ipv4 =~ /^127\.0\.0\.1$/ or die "doubleclick.com does not resolve to 127.0.0.1";
      my $ipv6 = $client->succeed("${pkgs.dnsutils}/bin/dig \@${virtualServiceIpv4} AAAA doubleclick.com +short");
      $ipv6 =~ /^::1$/ or die "doubleclick.com does not resolve to ::1";
    };
  '';
}
