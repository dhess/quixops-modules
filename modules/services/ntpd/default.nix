# Just like upstream ntpd, except this one allows an extraConfig. This
# should probably be upstreamed at some point.

{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) ntp;

  cfg = config.services.ntp;

  stateDir = "/var/lib/ntp";

  ntpUser = "ntp";

  configFile = pkgs.writeText "ntp.conf" ''
    driftfile ${stateDir}/ntp.drift

    restrict 127.0.0.1
    restrict -6 ::1

    ${toString (map (server: "server " + server + " iburst\n") cfg.servers)}
    ${cfg.extraConfig}
  '';

  ntpFlags = "-c ${configFile} -u ${ntpUser}:nogroup ${toString cfg.extraFlags}";

in

{

  disabledModules = [ "services/networking/ntpd.nix" ];

  ###### interface

  options = {

    services.ntp = {

      enable = mkOption {
        default = false;
        description = ''
          Whether to synchronise your machine's time using the NTP
          protocol.
        '';
      };

      servers = mkOption {
        default = config.networking.timeServers;
        description = ''
          The set of NTP servers from which to synchronise.
        '';
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        description = "Extra flags passed to the ntpd command.";
        default = [];
      };

      extraConfig = mkOption {
        type = types.lines;
        description = "Extra ntpd config that is appended to the default config file.";
        default = "";
      };

    };

  };


  ###### implementation

  config = mkIf config.services.ntp.enable {

    quixops.assertions.moduleHashes."services/networking/ntpd.nix" =
      "8f742ebd032e91e0bee51c6a16f4518a5af32cdbada3eef00ec8e776c4ceb811";

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

}
