{ stdenv, fetchFromGitHub, pkgs, bash, dash, dtc, sudo }:

let

  lib = import ../../../lib.nix;

  name = "bb-org-overlays-${version}";
  version = "20171215";
  rev = "8bc1d2a89f81763eefa62a3e7f44ab505ff582cf";
  sha256 = "120drcbji08r005x73yllq9wyi6a7lqma8bmmdmscdzs685nrm0y";

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

  patches = [ ./dtc-1.45.patch ];

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
