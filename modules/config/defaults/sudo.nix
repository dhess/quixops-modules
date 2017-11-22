# Safer sudo defaults.

{ config, ... }:

{
  config = {
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
