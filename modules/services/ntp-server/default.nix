{ config, pkgs, lib, ... }:

with lib;

let

  inherit (pkgs) ntp;

  cfg = config.services.ntp-server;
  ntpEnabled = config.services.ntp.enable;
  stateDir = "/var/lib/ntp";
  enabled = cfg.enable;
  ntpUser = "ntp";
  ntpFlags = "-c ${configFile} -u ${ntpUser}:nogroup";
  configFile = pkgs.writeText "ntp.conf" ''
    driftfile ${stateDir}/ntp.drift

    ${optionalString (cfg.listenIPs != []) ''
      interface ignore wildcard
      interface listen 127.0.0.1
      interface listen ::1
    ''}

    ${toString (map (ip: "interface listen ${ip}\n") cfg.listenIPs)}

    restrict -4 default kod notrap nomodify nopeer noquery limited
    restrict -6 default kod notrap nomodify nopeer noquery limited

    restrict 127.0.0.1
    restrict -6 ::1

    ${toString (map (server: "server " + server + " iburst\n") cfg.servers)}
  '';

in {

  options.services.ntp-server = {

    enable = mkEnableOption "An NTP configured to accept external client queries (securely).";

    servers = mkOption {
      type = types.nonEmptyListOf pkgs.lib.types.nonEmptyStr;
      description = ''
        A list of one or more upstream NTP servers (preferably between 4 and 7).
      '';
    };

    listenIPs = mkOption {
      type = types.listOf (types.either pkgs.lib.types.ipv4 pkgs.lib.types.ipv6);
      default = [];
      description = ''
        An optional list of IPs (both v4 and v6 are supported) on
        which <literal>ntpd</literal> will listen for client
        connections, <strong>and<strong> from which
        <literal>ntpd<literal> will connect to remote time servers. If
        you specify one or more addresses here, make sure that at
        least one of them can connect to the public Internet.

        If the list is empty (the default), then
        <literal>ntpd<literal> will listen on all addresses that are
        configured by the system.

        Note that this module will configure <literal>ntpd</literal>
        so that it always listens on <literal>127.0.0.1</literal> and
        <literal>::1</literal>, so there is no need to specify those
        addresses here.
      '';
    };

  };

  config = mkIf enabled {

    assertions = [
      { assertion = ! ntpEnabled;
        message = "Only one of 'services.ntp-server' and 'services.ntp' must be enabled";
      }
    ];

    quixops.assertions.moduleHashes."services/networking/ntpd.nix" =
      "660709cc9bd7b7269d7f91ac278d2d7b9f51a53ab02425c27778af2f405b9fe0";

    # Make tools such as ntpq available in the system path.
    environment.systemPackages = [ pkgs.ntp ];
    services.timesyncd.enable = mkForce false;

    users.users = singleton
      { name = ntpUser;
        uid = config.ids.uids.ntp;
        description = "NTP daemon user";
        home = stateDir;
      };

    systemd.services.ntpd =
      { description = "NTP Daemon";

        wantedBy = [ "multi-user.target" ];
        wants = [ "time-sync.target" ];
        before = [ "time-sync.target" ];

        preStart =
          ''
            mkdir -m 0755 -p ${stateDir}
            chown ${ntpUser} ${stateDir}
          '';

        serviceConfig = {
          ExecStart = "@${ntp}/bin/ntpd ntpd -g ${ntpFlags}";
          Type = "forking";
        };
      };

  };

  meta.maintainers = lib.maintainers.dhess-qx;
}
