self: super:

let

  lib = import ../lib.nix;
  inherit (super) pkgs;
  inherit (pkgs) callPackage;

in rec {

  bb-org-overlays = callPackage ./pkgs/hardware/bb-org-overlays.nix {};

  ffmpeg-snapshot = callPackage ./pkgs/multimedia/ffmpeg-snapshot.nix rec {
    inherit (self.pkgs.darwin.apple_sdk.frameworks) Cocoa CoreMedia;
    branch = "20171128.86cead5";
    version = branch;
    rev = "86cead525633cd6114824b33a74d71be677f9546";
    sha256 = "07a0qwr0rd4shbm41n0dg6ip4vb39kxns7qlh1jd81zmvs3xqi0n";
  };

  unbound-block-hosts = callPackage ./pkgs/dns/unbound-block-hosts.nix {};

}
