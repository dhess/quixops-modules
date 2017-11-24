{ config, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.networking;
  enabled = cfg.enable;

in
{
  options.quixops.defaults.networking = {

    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the Quixops networking configuration defaults.
      '';
    };

  };

  config = mkIf enabled {

    # Don't use DNSSEC.
    networking.dnsExtensionMechanism = false;
    networking.firewall.allowPing = true;

  };

}
