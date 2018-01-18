{ system
, pkgs
, modules
, makeTest
, ... }:

let

  # Don't do this in production -- it will put the secrets into the
  # Nix store! This is just a convenience for the tests.

  pwhash = pkgs.copyPathToStore ./testfiles/hydra-pw-hash;
  bcpubkey = pkgs.copyPathToStore ./testfiles/hydra-1/public;
  bckey = pkgs.copyPathToStore ./testfiles/hydra-1/secret;
  bcKeyDir = "/etc/nix/hydra-1";

  commonSetupConfig = { config, lib, pkgs, nodes, ... }: {
    services.hydra-manual-setup = {
      enable = true;
      adminUser = {
        fullName = "Hydra Admin";
        userName = "hydra";
        email = "hydra@example.com";
        # foobar
        initialPasswordHash = "${pwhash}";
      };
      binaryCacheKey = {
        public = ./testfiles/hydra-1/public;
        private = "${bckey}";
        directory = "${bcKeyDir}";
      };
    };
  };

  commonHydraConfig = { config, lib, pkgs, nodes, ... }: {
    services.hydra = {
      enable = true;
      hydraURL = "http://hydra";
      notificationSender = "notifier@example.com";
    };
  };

in makeTest rec {
  name = "hydra-manual-setup";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {

    # Here hydra-manual-setup is enabled, but hydra is not. The hydra
    # service should not be enabled just because hydra-manual-setup
    # is.
    
    nohydra = { config, pkgs, ... }: {
      imports = [ commonSetupConfig ] ++ modules;
    };

    # Here hydra is enabled, but hydra-manual-setup is not. The
    # hydra-manual-setup service should not run in this case.
    
    nosetup = { config, pkgs, ... }: {
      imports = [ commonHydraConfig ] ++ modules;
    };

    # Here both services are enabled.

    hydra = { config, pkgs, ... }: {
      imports = [
        commonSetupConfig
        commonHydraConfig
      ] ++ modules;
    };

  };

  testScript = { nodes, ... }:
  let
  in ''
    $nohydra->waitForUnit("multi-user.target");
    subtest "check-no-hydra", sub {
      $nohydra->fail("systemctl status hydra-manual-setup.service");
      $nohydra->fail("systemctl status hydra.service");
    };

    $nosetup->waitForUnit("multi-user.target");
    subtest "check-no-manual-setup", sub {
      # test whether the database is running
      $nosetup->succeed("systemctl status postgresql.service");
      # test whether the actual hydra daemons are running
      $nosetup->succeed("systemctl status hydra-queue-runner.service");
      $nosetup->succeed("systemctl status hydra-init.service");
      $nosetup->succeed("systemctl status hydra-evaluator.service");
      $nosetup->succeed("systemctl status hydra-send-stats.service");
      $nosetup->fail("systemctl status hydra-manual-setup.service");
    };

    $hydra->waitForUnit("multi-user.target");
    subtest "check-manual-setup", sub {

      # test whether the database is running
      $hydra->succeed("systemctl status postgresql.service");

      # test whether the actual hydra daemons are running
      $hydra->succeed("systemctl status hydra-queue-runner.service");
      $hydra->succeed("systemctl status hydra-init.service");
      $hydra->succeed("systemctl status hydra-evaluator.service");
      $hydra->succeed("systemctl status hydra-send-stats.service");
      $hydra->succeed("systemctl status hydra-manual-setup.service");

      # Make sure binary cache keys were copied to the expected
      # location with the proper permissions.
      $hydra->succeed("[[ -d ${bcKeyDir} ]]");
      $hydra->succeed("[[ `stat -c%a ${bcKeyDir}` -eq 551 ]]");
      $hydra->succeed("[[ `stat -c%U ${bcKeyDir}` -eq hydra ]]");
      $hydra->succeed("[[ `stat -c%G ${bcKeyDir}` -eq hydra ]]");
      $hydra->succeed("[[ -e ${bcKeyDir}/public ]]");
      $hydra->succeed("[[ `stat -c%a ${bcKeyDir}/public` -eq 444 ]]");
      $hydra->succeed("[[ `stat -c%U ${bcKeyDir}/public` -eq hydra ]]");
      $hydra->succeed("[[ `stat -c%G ${bcKeyDir}/public` -eq hydra ]]");
      $hydra->succeed("[[ -e ${bcKeyDir}/secret ]]");
      $hydra->succeed("[[ `stat -c%a ${bcKeyDir}/secret` -eq 440 ]]");
      $hydra->succeed("[[ `stat -c%U ${bcKeyDir}/secret` -eq hydra ]]");
      $hydra->succeed("[[ `stat -c%G ${bcKeyDir}/secret` -eq hydra ]]");
      $hydra->succeed("diff ${bcKeyDir}/public ${bcpubkey}");
      $hydra->succeed("diff ${bcKeyDir}/secret ${bckey}");
    };

  '';
}
