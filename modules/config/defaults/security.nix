{ config, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.security;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.security = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops security configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    boot.cleanTmpDir = true;

  };
}
