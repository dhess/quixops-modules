let

  localLib = import ./lib.nix;

in

{ pkgs ? (import (localLib.fetchNixPkgs) { system = "x86_64-linux"; })
, supportedSystems ? [ "x86_64-linux" ]
}:

let

  forAllSystems = pkgs.lib.genAttrs supportedSystems;

  importTest = fn: args: system: import fn ({
    inherit system;
  } // args);

  callTest = fn: args: forAllSystems (system: (importTest fn args system));

in rec {

  tests.test = callTest tests/test.nix {};

}
