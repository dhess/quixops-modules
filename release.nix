{ nixpkgs ? (import ./fetch-nixpkgs.nix)
, supportedSystems ? [ "x86_64-linux" ]
}:

let

  pkgs = import nixpkgs { system = "x86_64-linux"; };

  forAllSystems = pkgs.lib.genAttrs supportedSystems;

  importTest = fn: args: system: import fn ({
    inherit system;
  } // args);

  callTest = fn: args: forAllSystems (system: (importTest fn args system));

in rec {

  tests.test = callTest tests/test.nix {};

}
