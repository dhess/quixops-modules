self: super:

let

  stdenv = super.stdenv;

  haskellLib = super.haskell.lib;

  callHaskellPackage = super.newScope { inherit haskellLib; };

  ghc801bin = callHaskellPackage ./pkgs/haskell/8.0.1-binary.nix { };
  ghc802From801Binary = callHaskellPackage ./pkgs/haskell/8.0.2.nix {
    ghc = ghc801bin;
    sphinx = super.pkgs.python27Packages.sphinx;
  };

in
rec {

  haskell = super.haskell // {
    compiler = super.haskell.compiler // {
      ghc801Binary = ghc801bin;
    };
    packages = super.haskell.packages //
      (if stdenv.system == "armv7l-linux" || stdenv.system == "aarch64-linux" then {

        ghc802 = callHaskellPackage <nixpkgs/pkgs/development/haskell-modules> {
          ghc = ghc802From801Binary;
          compilerConfig = callHaskellPackage <nixpkgs/pkgs/development/haskell-modules/configuration-ghc-8.0.x.nix> { };
        };

      } else {});
  };

  haskellPackages =
  with super.pkgs.haskell.lib;
  super.haskellPackages.extend (self: super:
  {
    happy = if stdenv.system == "armv7l-linux" then dontCheck super.happy else super.happy;
    hashable = if stdenv.system == "armv7l-linux" then dontCheck super.hashable else super.hashable;
    servant-docs = if stdenv.system == "armv7l-linux" then dontCheck super.servant-docs else super.servant-docs;
    servant-swagger = if stdenv.system == "armv7l-linux" then dontCheck super.servant-swagger else super.servant-swagger;
    swagger2 = if stdenv.system == "armv7l-linux" then dontCheck super.swagger2 else super.swagger2;
  });

}
