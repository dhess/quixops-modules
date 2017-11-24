let

  # From https://github.com/input-output-hk/iohk-ops/blob/e6f1ae95cdbfdd5c213aa0b9a1ef67150febc503/lib.nix
  
  fetchNixPkgs =
  let
    try = builtins.tryEval <quixops_pkgs>;
  in
    if try.success
      then builtins.trace "Using <quixops_pkgs>" try.value
      else import ./fetch-nixpkgs.nix;

  pkgs = import fetchNixPkgs {};
  lib = pkgs.lib;
  
in lib // (rec {

  quixopsModules = (import ./default.nix).modules;

  inherit fetchNixPkgs;


  ## Test harness.
  #

  importTest = fn: args: system: import fn ({
    inherit system;
  } // args);

  callTest = forSystems: fn: args: forSystems (system: lib.hydraJob (importTest fn args system));

  callSubTests = supportedSystems: fn: args: let
    discover = attrs: let
      subTests = lib.filterAttrs (lib.const (lib.hasAttr "test")) attrs;
    in lib.mapAttrs (lib.const (t: lib.hydraJob t.test)) subTests;

    discoverForSystem = system: lib.mapAttrs (_: test: {
      ${system} = test;
    }) (discover (importTest fn args system));

  # If the test is only for a particular system, use only the specified
  # system instead of generating attributes for all available systems.
  in if args ? system then discover (import fn args)
     else lib.foldAttrs lib.mergeAttrs {} (map discoverForSystem supportedSystems);

  ## Local maintainers.
  #

  quixopsMaintainers = {
    dhess = "Drew Hess <dhess-src@quixoftic.com>";
  };

})
