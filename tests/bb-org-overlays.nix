{ system ? "armv7l-linux"
, pkgs
, makeTest
, ... }:


let

  makeBBOverlaysTest = name: machineAttrs:
    makeTest {
      name = "bb-org-overlays-${name}";
      meta = with pkgs.lib.maintainers; {
        maintainers = [ dhess-qx ];
      };
      machine = { config, ... }: {
        imports = [
          ./common/users.nix
        ] ++ (import pkgs.lib.quixops.modulesPath);
      } // machineAttrs;
      testScript = { nodes, ... }:
      let
        pkgs = nodes.machine.pkgs;
      in
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
