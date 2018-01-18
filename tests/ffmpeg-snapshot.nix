{ system
, pkgs
, modules
, makeTest
, ... }:

let

  makeFfmpegSnapshotTest = name: machineAttrs:
    makeTest {
      name = "ffmpeg-snapshot-${name}";
      meta = with pkgs.lib.maintainers; {
        maintainers = [ dhess-qx ];
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

        subtest "ffmpeg-snapshot", sub {
          $machine->succeed("${pkgs.ffmpeg-snapshot}/bin/ffmpeg -version");
        };
      '';
    };

in
{

  defaultTest = makeFfmpegSnapshotTest "default" { };

}
