## Note: the local overlays are always enabled. Our own modules rely
## on them.

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults;

in
{
  config = {
    nixpkgs.overlays = [ (import ../../.) ];
  };
}
