let

  lib = import ../lib.nix;
  quixopsModules = (import ../.).modules;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, makeTest
, ... }:


let

  makeSecurityTest = name: machineAttrs:
    makeTest {

      name = "security-${name}";

      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };

      machine = { config, pkgs, ... }: {

        imports = [
        ] ++ quixopsModules;

      } // machineAttrs;

      testScript = { ... }:
      ''
        $machine->waitForUnit("multi-user.target");

        subtest "clean-tmpdir-on-boot", sub {
          $machine->succeed("touch /tmp/foobar");
          $machine->shutdown;
          $machine->waitForUnit("systemd-tmpfiles-clean.timer");
          $machine->succeed("! [ -e /tmp/foobar ]");
        };
      '';

    };

in
{

  test1 = makeSecurityTest "global-enable" { quixops.defaults.enable = true; };
  test2 = makeSecurityTest "security-enable" { quixops.defaults.security.enable = true; };

}
