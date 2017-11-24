{ config, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.users;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.users = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops user configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    users.mutableUsers = false;

  };
}
