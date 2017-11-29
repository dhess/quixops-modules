self: super:

let

  lib = import ../lib.nix;
  inherit (super) pkgs;
  inherit (pkgs) callPackage;

in rec {

  bb-org-overlays = callPackage ./pkgs/hardware/bb-org-overlays.nix {};

  unbound-block-hosts = callPackage ./pkgs/dns/unbound-block-hosts.nix {};

}
