self: super:

let

  lib = import ../lib.nix;
  inherit (super) pkgs;
  inherit (pkgs) callPackage;

in rec {

  # 0.6.3.
  netsniff-ng = callPackage ./pkgs/networking/netsniff-ng {};

}
