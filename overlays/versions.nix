self: super:

let

  lib = import ../lib.nix;
  inherit (super) pkgs;
  inherit (pkgs) callPackage;

in rec {

  netsniff-ng = callPackage ./pkgs/networking/netsniff-ng {};

}
