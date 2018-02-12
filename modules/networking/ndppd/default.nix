{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.services.ndppd;

  configFile = pkgs.writeText "ndppd.conf" ''
    ${cfg.config}
  '';

in {

  options.services.ndppd = {
    enable = mkEnableOption "Enable the ndppd service.";

    config = mkOption {
      type = types.lines;
      description = ''
        The literal ndppd service configuration.
      '';
    };
  };

  config = mkIf cfg.enable {

    systemd.services.ndppd = {
      description = "NDP proxy daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      script = "${pkgs.ndppd}/bin/ndppd -v -c ${configFile}";
      restartIfChanged = true;
    };

    meta = {
      maintainers = lib.maintainers.dhess-qx;
    };

  };

}
