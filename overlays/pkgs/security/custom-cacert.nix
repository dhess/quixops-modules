{ stdenv, cacert, pkgs, extraCerts ? {} }:

let

  inherit (stdenv) lib;

  extraCAs = pkgs.writeText "extraCAs"
  (lib.concatStrings
    (lib.mapAttrsToList
      (caName: caPem:
        ''
          ${caName}
          ${caPem}
        '')
      extraCerts));

in
lib.overrideDerivation cacert (oldAttrs: {

  installPhase = ''
    mkdir -pv $out/etc/ssl/certs
    cat ca-bundle.crt ${extraCAs} > $out/etc/ssl/certs/ca-bundle.crt
  '';

})
