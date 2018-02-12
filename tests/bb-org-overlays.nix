{ system ? "armv7l-linux"
, pkgs
, makeTest
, ...
}:


let

  makeBBOverlaysTest = name: machineAttrs:
    makeTest {
      name = "bb-org-overlays-${name}";
      meta = with pkgs.lib.maintainers; {
        maintainers = [ dhess-qx ];
      };
      machine = { config, ... }: {
        nixpkgs.system = system;
        imports = (import pkgs.lib.quixops.modulesPath);
      } // machineAttrs;
      testScript = { nodes, ... }:
      ''
        $machine->waitForUnit("multi-user.target");

        subtest "config-pin", sub {
          $machine->succeed("${pkgs.bb-org-overlays}/bin/config-pin -v");
        };
      '';
    };

in
{

  defaultTest = makeBBOverlaysTest "default" { };

}
