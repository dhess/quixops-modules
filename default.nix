# NOTE: do not use ./lib.nix here, because it imports this module.

let

in rec {

  modules = import ./modules/module-list.nix;

  overlays = [
    (import ./overlays/default.nix)
  ];

}
