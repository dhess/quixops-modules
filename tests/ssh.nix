let

  lib = import ../lib.nix;

in

import <nixpkgs/nixos/tests/make-test.nix> ({ pkgs, ... }: {

  name = "ssh";

  machine = { config, pkgs, ... }: {
      imports = lib.quixopsModules;
  };

  testScript  = ''
    $machine->waitForUnit("sshd.service");
    $machine->waitForOpenPort(22);
  '';

})
