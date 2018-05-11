# Note: using disabledModules here to disable upstream's bird2 service
# doesn't work. It might have something to do with the odd way that
# module is written.
#
# In any case, here we just define a service named `qx-bird2`.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.qx-bird2;
  enabled = cfg.enable;
  configFile = "/etc/bird2/bird2.conf";
  keychain = config.quixops.keychain.keys;

in
{
  # Doesn't work, see note above.
  #disabledModules = [ "services/networking/bird.nix" ];

  options.services.qx-bird2 = {

    enable = mkEnableOption "BIRD internet routing daemon (v2)";

    config = mkOption {
      type = types.lines;
      example = literalExample ''
        log syslog all;
        router id 10.10.10.10;
        protocol device {
        }
        protocol kernel kernel4 {
            ipv4 {
                export all;
            };
        }
        protocol kernel kernel6 {
            ipv6 {
                export all;
            };
        }
      '';
      description = ''
        The literal BIRD configuration.

        As this configuration may contain secrets, its contents will
        not be copied to the Nix store. However, upon start-up, the
        service will copy a file containing this configuration to a
        persistent directory on the host.
      '';
    };    

  };

  config = mkIf enabled {

    quixops.assertions.moduleHashes."services/networking/bird.nix" =
      "e27600d2ff6640e16ed4b5354c44c316710ee2730c1152c94ca06c66196d837b";

    quixops.keychain.keys.bird2-config = {
      text = cfg.config;
    };

    environment.systemPackages = with pkgs; [ bird2 ];

    # This must be a separate service, and not just a pre-script for
    # the bird2 service, because of the CAP restrictions on the bird2
    # service.
    
    systemd.services.bird2-setup = {
      description = "BIRD Internet Routing Daemon (v2) setup script";
      requiredBy = [ "bird2.service" ];
      before = [ "bird2.service" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" ];
      script = ''
        install -m 0555 -d `dirname ${configFile}`
        install -m 0400 -o bird -g bird ${keychain.bird2-config.path} ${configFile}
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.bird2 = lib.mkForce {
      description = "BIRD Internet Routing Daemon (v2)";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "forking";
        Restart = "on-failure";
        ExecStart = "${pkgs.bird2}/bin/bird -c ${configFile} -u bird -g bird";
        ExecReload = "${pkgs.bird2}/bin/birdc configure";
        ExecStop = "${pkgs.bird2}/bin/birdc down";
        CapabilityBoundingSet = [ "CAP_CHOWN" "CAP_FOWNER" "CAP_DAC_OVERRIDE" "CAP_SETUID" "CAP_SETGID"
                                  # see bird/sysdep/linux/syspriv.h
                                  "CAP_NET_BIND_SERVICE" "CAP_NET_BROADCAST" "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        ProtectSystem = "full";
        ProtectHome = "yes";
        SystemCallFilter="~@cpu-emulation @debug @keyring @module @mount @obsolete @raw-io";
        MemoryDenyWriteExecute = "yes";
      };
    };

    users.users.bird = {
        description = "BIRD Internet Routing Daemon user";
        group = "bird";
    };
    users.groups.bird = {};

  };

  meta.maintainers = maintainers.dhess-qx;
}

