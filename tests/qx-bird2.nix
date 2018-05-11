{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

makeTest {
  name = "qx-bird2";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {

    server = { config, ... }: {
      nixpkgs.localSystem.system = system;
      imports =
        (import pkgs.lib.quixops.modulesPath) ++
        (import pkgs.lib.quixops.testModulesPath);

      # Use the test key deployment system.
      deployment.reallyReallyEnable = true;

      services.qx-bird2 = {
        enable = true;
        config = ''
          log syslog all;
          router id 10.10.10.10;
          protocol device {
          }
          protocol kernel kernel4 {
              ipv4 {
                  export all;
              };
          }
          protocol kernel kernel6 {
              ipv6 {
                  export all;
              };
          }
        '';
      };
    };

  };

  testScript = { nodes, ... }:
  let
  in ''
    startAll;

    $server->waitForUnit("bird2.service");
  '';
}
