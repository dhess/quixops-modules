# Note -- this service can't actually communicate with AWS. It's
# mainly here just to make sure that pinpon compiles.

{ system ? "x86_64-linux"
, pkgs
, makeTest
, ...
}:

let

  # NOTE -- these are not actual credentials. They are sourced from
  # this Amazon documentation:
  # https://docs.aws.amazon.com/cli/latest/userguide/cli-config-files.html
  
  creds = ''
    [pinpon]
    aws_access_key_id=AKIAIOSFODNN7EXAMPLE
    aws_secret_access_key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
  '';

in makeTest rec {
  name = "pinpon";

  meta = with pkgs.lib.maintainers; {
    maintainers = [ dhess-qx ];
  };

  nodes = {
    server = { config, ... }: {
      nixpkgs.localSystem.system = system;
      imports =
        (import pkgs.lib.quixops.modulesPath) ++
        (import pkgs.lib.quixops.testModulesPath);

      # Use the test key deployment system.
      deployment.reallyReallyEnable = true;

      services.pinpon = {
        enable = true;
        port = 3333;
        snsTopicName = "front-door";
        snsPlatform = "APNSSandbox";
        awsRegion = "us-east-1";
        awsCredentialsLiteral = creds;
        awsProfile = "pinpon";
        description = "Test PinPon server";
      };
    };
  };

  testScript = { nodes, ... }:
  ''
    startAll;

    $server->waitForUnit("pinpon.service");
  '';
}
