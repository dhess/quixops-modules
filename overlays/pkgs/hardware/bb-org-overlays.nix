{ stdenv, fetchFromGitHub, pkgs, bash, dash, dtc, sudo }:

let

  lib = import ../../../lib.nix;

  name = "bb-org-overlays-${version}";
  version = "20171107";
  rev = "b25f6aa6ae0fa7eae6b33902044bd0aacfde9bb2";
  sha256 = "1sky57dyplvsisbqyc2ccx2cap3fprvfarfq0p3wil63qd96pi1c";

in
stdenv.mkDerivation rec {
  inherit name version;

  src = fetchFromGitHub {
    owner = "beagleboard";
    repo = "bb.org-overlays";
    inherit rev sha256;
  };

  buildInputs = [ dtc ];
  propagatedBuildInputs = [ dash bash sudo ];

  postPatch = ''
    substituteInPlace tools/beaglebone-universal-io/config-pin --replace "sudo" "${sudo}/bin/sudo"
    substituteInPlace tools/beaglebone-universal-io/config-pin --replace "bash" "${bash}/bin/bash"
  '';

  makeFlags = [ "DTC=${dtc}/bin/dtc" "DESTDIR=$(out)" ];

  installPhase = ''
    make install DESTDIR=$out
    mkdir -p $out/bin
    cp tools/beaglebone-universal-io/config-pin $out/bin
  '';

  meta = {
    homepage = https://github.com/beagleboard/bb.org-overlays/;
    description = "Device Tree Overlays for bb.org boards";
    maintainers = lib.maintainers.dhess;
    license = pkgs.lib.licenses.gpl2;
    platforms = [ "armv7l-linux" ];
  };
}
