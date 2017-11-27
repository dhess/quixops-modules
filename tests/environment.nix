let

  lib = import ../lib.nix;

in

{ system ? builtins.currentSystem
, pkgs ? (import lib.fetchNixPkgs) { inherit system; }
, ... }:


let

  makeEnvTest = name: machineAttrs:
    lib.makeTest {
      name = "environment-${name}";
      meta = with lib.quixopsMaintainers; {
        maintainers = [ dhess ];
      };
      machine = { config, pkgs, ... }: {
        imports = [
          ./common/users.nix
        ] ++ lib.quixopsModules;
      } // machineAttrs;
      testScript = { ... }:
      ''
        $machine->waitForUnit("multi-user.target");

        subtest "root-no-histfile", sub {
          my $histfile = $machine->fail("${pkgs.bash}/bin/bash -c 'printenv HISTFILE'");
          $histfile eq "" or die "Unexpected output from 'printenv HISTFILE'";
        };

        subtest "user-no-histfile", sub {
          my $whoami = $machine->succeed("su - alice -c 'whoami'");
          $whoami eq "alice\n" or die "su failed";
          my $histfile = $machine->fail("su - alice -c 'printenv HISTFILE'");
          $histfile eq "" or die "Unexpected output from 'printenv HISTFILE'";
        };

        subtest "git-is-in-path", sub {
          $machine->succeed("git init") =~ /Initialized empty Git repository in/;
        };

        subtest "wget-is-in-path", sub {
          $machine->succeed("wget --version") =~ /GNU Wget/;
        };
      '';
    };

in
{

  test1 = makeEnvTest "global-enable" { quixops.defaults.enable = true; };
  test2 = makeEnvTest "env-enable" { quixops.defaults.environment.enable = true; };

}
