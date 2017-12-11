{ stdenv, makeWrapper, pkgs, perl, perlPackages, ethtool }:

let

in
stdenv.mkDerivation rec {

  name = "tsoff";
  version = "1.0";
  src = ./.;

  buildInputs = [
    makeWrapper
    perl
    perlPackages.GetoptLong
    perlPackages.LogLog4perl
    perlPackages.PodUsage
  ];

  installPhase = let path = stdenv.lib.makeBinPath [
    ethtool
  ]; in ''
    mkdir -p $out/bin
    cp tsoff $out/bin
    chmod 0755 $out/bin/tsoff
    wrapProgram $out/bin/tsoff --set PERL5LIB $PERL5LIB --prefix PATH : "${path}"
  '';

  meta = {
    description = "Disable TSO features on an Ethernet NIC";
    maintainers = [ "Drew Hess <src@drewhess.com>" ];
    license = pkgs.lib.licenses.mit;
  };
}
