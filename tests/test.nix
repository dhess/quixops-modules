let

in

import <nixpkgs/nixos/tests/make-test.nix> ({ pkgs, ... }: {

  name = "test";

  nodes = {
    machine = { config, pkgs, ... }: {
      imports = [];
      services.sshd.enable = true;
    };
  };

  testScript  = ''
    startAll
    $machine->waitForUnit("sshd.service");
    $machine->waitForOpenPort(22);
  '';

})
