let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, ... }:


let

  makeSystemTest = name: machineAttrs:
    lib.makeTest {
      name = "system-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };
      machine = { config, pkgs, ... }: {
        imports = [
        ] ++ lib.quixopsModules;
      } // machineAttrs;
      testScript = { ... }:
      ''
        $machine->waitForUnit("multi-user.target");

        subtest "timezone-is-utc", sub {
          my $timedatectl = $machine->succeed("timedatectl");
          $timedatectl =~ /Time zone: Etc\/UTC/ or die "System has wrong timezone";
        };

        subtest "locale-is-utf8", sub {
          my $localectl = $machine->succeed("localectl");
          $localectl =~ /System Locale: LANG=en_US.UTF-8/ or die "System has wrong locale";
        };

        subtest "logrotate-enabled", sub {
          $machine->waitForUnit("logrotate.timer");
        };
      '';
    };

in
{

  globalEnableTest = makeSystemTest "global-enable" { quixops.defaults.enable = true; };
  systemEnableTest = makeSystemTest "system-enable" { quixops.defaults.system.enable = true; };

}