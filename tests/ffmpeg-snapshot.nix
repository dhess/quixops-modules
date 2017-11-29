let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, ... }:


let

  testing = import <nixpkgs/nixos/lib/testing.nix> { inherit system; };
  inherit (testing) makeTest;

  makeFfmpegSnapshotTest = name: machineAttrs:
    makeTest {
      name = "ffmpeg-snapshot-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };
      machine = { config, pkgs, ... }: {
        imports = [
          ./common/users.nix
        ] ++ lib.quixopsModules;
        nixpkgs.overlays = lib.quixopsOverlays;
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
