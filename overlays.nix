let

  localLib = import ./lib.nix;

in
[
  localLib.fetchNixPkgsQuixoftic
  localLib.fetchNixPkgsLibQuixoftic
  ./overlays/lib.nix
]
