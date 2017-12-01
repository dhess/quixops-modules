let
  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, ... }:


let

  testing = import <nixpkgs/nixos/lib/testing.nix> { inherit system; };
  inherit (testing) makeTest;
  modulesLib = lib.quixopsModulesLib;

  makeZncTest = name: machineAttrs:
    makeTest {
      name = "znc-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };

      machine = { config, pkgs, ... }:
      {
        imports = [
          ./common/users.nix
        ] ++ lib.quixopsModules;
        nixpkgs.overlays = lib.quixopsOverlays;

        services.znc = {
          enable = true;
          mutable = false;
          configFile = "/var/run/znc.conf";
          confOptions = {
            userName = "bob-znc";
            nick = "bob";
            passBlock = "
              <Pass password>
                Method = sha256
                Hash = e2ce303c7ea75c571d80d8540a8699b46535be6a085be3414947d638e48d9e93
                Salt = l5Xryew4g*!oa(ECfX2o
              </Pass>
            ";
          };
        };

      } // machineAttrs;

      testScript = { nodes, ... }:
      let
        zncConf = pkgs.writeText "znc.conf" (modulesLib.mkZncConfig {
          inherit lib;
          zncServiceConfig = nodes.machine.config.services.znc;
        });
      in
      ''
        # Don't have a good way to synchronize this without NixOps, so
        # we just restart the znc service after the config file has
        # been copied to the server.
        $machine->copyFileFromHost("${zncConf}", "${nodes.machine.config.services.znc.configFile}");
        $machine->waitForUnit("znc.service");
      '';
    };

in
{

  defaultTest = makeZncTest "default" { };

}
