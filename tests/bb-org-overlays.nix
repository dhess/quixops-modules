{ system ? "armv7l-linux"
, pkgs
, modules
, makeTest
, ... }:


let

  makeBBOverlaysTest = name: machineAttrs:
    makeTest {
      name = "bb-org-overlays-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };
      machine = { config, pkgs, ... }: {
        imports = [
          ./common/users.nix
        ] ++ modules;
        quixops.defaults.overlays.enable = true;
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
