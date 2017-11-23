let

  quixopsModules = (import ../.).modules;

in

import <nixpkgs/nixos/tests/make-test.nix> ({ pkgs, ... }: {

  name = "ssh";

  machine = { config, pkgs, ... }: {
      imports = quixopsModules;
  };

  testScript  = ''
    $machine->waitForUnit("sshd.service");
    $machine->waitForOpenPort(22);
  '';

})
