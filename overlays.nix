let

  localLib = import ./lib.nix;

in
[
  localLib.fetchNixPkgsQuixoftic
  localLib.fetchNixPkgsLibQuixoftic
  ./overlays/lib/quixops-modules.nix
  ./overlays/lib/types.nix
]
