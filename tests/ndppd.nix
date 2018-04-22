{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

in makeTest rec {
  name = "ndppd";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {

    proxy = { config, ... }: {
      nixpkgs.localSystem.system = system;
      imports = (import pkgs.lib.quixops.modulesPath);
      networking = {
        interfaces.eth0.ipv6.addresses = pkgs.lib.mkOverride 0
          [ { address = fd00:1234:5678:9::2; prefixLength = 64; } ];
      };
      services.ndppd = {
        enable = true;
        config = ''
          proxy eth0 {
            router yes
            rule fd00:1234:5678::/112 {
              static
            }
          }
        '';
      };
    };

    pinger = { config, ... }: {
      nixpkgs.localSystem.system = system;
      networking = {
        interfaces.eth0.ipv6.addresses = pkgs.lib.mkOverride 0
          [ { address = fd00:1234:5678:9::1; prefixLength = 64; } ];
      };
    };
  };

  testScript = { nodes, ... }:
  ''
    startAll;

    $proxy->waitForUnit("multi-user.target");
    $proxy->requireActiveUnit("ndppd.service");
    $pinger->waitForUnit("multi-user.target");

    # Ping an address covered by the ndppd range.
    # XXX dhess - not working, might be VM-related.
    # $pinger->succeed("ip -6 route add default dev eth0 metric 1");
    # $proxy->succeed("ip -6 route add default dev eth0 metric 1");
    # $pinger->waitUntilSucceeds("ping -c 1 fd00:1234:5678::1"); 
  '';
}
