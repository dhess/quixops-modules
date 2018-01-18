{ system
, pkgs
, makeTest
, ... }:


let

  makeNetworkingTest = name: machineAttrs: makeTest {

    name = "networking-${name}";

    meta = with pkgs.lib.maintainers; {
      maintainers = [ dhess-qx ];
    };

    nodes = {

      server = { config, ... }: {
        imports = (import pkgs.lib.quixops.modulesPath);
      } // machineAttrs;

      client = { ... }: {
      };

    };

    testScript = { nodes, ... }:
    ''
      startAll;
      $client->waitForUnit("network.target");
      $server->waitForUnit("network.target");

      subtest "can-ping", sub {
        $client->succeed("ping -c 1 server >&2");
      };
    '';

  };

in
{

  test1 = makeNetworkingTest "global-enable" { quixops.defaults.enable = true; };
  test2 = makeNetworkingTest "networking-enable" { quixops.defaults.networking.enable = true; };

}
