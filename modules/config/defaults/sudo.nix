# Safer sudo defaults.

{ config, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.sudo;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.sudo = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops sudo configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    # If we don't reset TZ, services that are started in a sudo shell
    # might use the user's original timezone settings, rather than the
    # system's.
    security.sudo.extraConfig =
      ''
        Defaults        !lecture,tty_tickets,!fqdn,always_set_home,env_reset,env_file="/etc/sudo.env"
        Defaults        env_keep -= TZ
        Defaults        env_keep -= TMOUT
        Defaults        env_keep -= HISTFILE
      '';

    # Don't save shell history and time out idle shells.
    environment.etc."sudo.env".text =
      ''
        export TMOUT=120
        export HISTFILE=
      '';
    environment.etc."sudo.env".mode = "0640";

  };
}
