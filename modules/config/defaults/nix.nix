{ config, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.nix;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.nix = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops Nix configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    nix.useSandbox = true;
    nixpkgs.config.allowUnfree = true;

  };

}
