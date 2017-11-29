self: super:

let

  lib = import ../lib.nix;
  inherit (super) pkgs;
  inherit (pkgs) callPackage;

in rec {

  unbound-block-hosts = callPackage pkgs/dns/unbound-block-hosts.nix {};

}
