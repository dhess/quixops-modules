let
  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, makeTest
, ... }:


let

  modulesLib = lib.quixopsModulesLib;

  makeZncTest = name: machineAttrs:
    makeTest {
      name = "znc-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };

      nodes = {

        localhostServer = { config, pkgs, ... }:
        {
          imports = [
          ] ++ lib.quixopsModules;
          nixpkgs.overlays = lib.quixopsOverlays;

          services.znc = {
            enable = true;
            mutable = false;
            openFirewall = true;
            configFile = "/var/run/znc.conf";
            confOptions = {
              host = "localhost";
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
        };

        server = { config, pkgs, ... }:
        {
          imports = [
          ] ++ lib.quixopsModules;
          nixpkgs.overlays = lib.quixopsOverlays;

          services.znc = {
            enable = true;
            mutable = false;
            openFirewall = true;
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
        };

        client = { config, pkgs, ... }:
        {
        };

      } // machineAttrs;

      testScript = { nodes, ... }:
      let
        serverZncConf = pkgs.writeText "znc.conf" (modulesLib.mkZncConfig {
          inherit lib;
          zncServiceConfig = nodes.server.config.services.znc;
        });
        localhostServerZncConf = pkgs.writeText "znc.conf" (modulesLib.mkZncConfig {
          inherit lib;
          zncServiceConfig = nodes.localhostServer.config.services.znc;
        });
      in
      ''
        startAll;

        # Don't have a good way to synchronize this without NixOps, so
        # we just restart the znc service after the config file has
        # been copied to the server.
        $server->copyFileFromHost("${serverZncConf}", "${nodes.server.config.services.znc.configFile}");
        $localhostServer->copyFileFromHost("${localhostServerZncConf}", "${nodes.localhostServer.config.services.znc.configFile}");
        $server->waitForUnit("znc.service");
        $localhostServer->waitForUnit("znc.service");

        subtest "no-remote-connections", sub {
          $client->fail("${pkgs.netcat}/bin/nc -w 5 localhostServer ${builtins.toString nodes.localhostServer.config.services.znc.confOptions.port}");
        };

        subtest "localhost-connections", sub {
          $localhostServer->succeed("${pkgs.netcat}/bin/nc -w 5 localhost ${builtins.toString nodes.localhostServer.config.services.znc.confOptions.port}");
        };

        subtest "allow-remote-connections", sub {
          $client->succeed("${pkgs.netcat}/bin/nc -w 5 server ${builtins.toString nodes.server.config.services.znc.confOptions.port}");
        };
      '';

    };

in
{

  defaultTest = makeZncTest "default" { };

}
