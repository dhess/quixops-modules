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

  inherit fetchNixPkgs;

})
