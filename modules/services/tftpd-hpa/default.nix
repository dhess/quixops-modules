{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.services.tftpd-hpa;

  # tftp-hpa requires IPv6 addresses to be enclosed in brackets.
  addressOption =
  let
    addr = cfg.listenAddress;
  in
    if addr == null then "" else
    if pkgs.lib.ipaddr.isIPv4NoCIDR addr then "--address ${addr}" else
    "--address [${addr}]";

in

{

  options = {

    services.tftpd-hpa = {

      enable = mkEnableOption ''
        Enable hpa's original TFTP server.

        The server will be run in standalone (listen) mode and will
        accept connections on the listen address (see the
        <option>listenAddress</option>) on port 69.
      '';

      root = mkOption {
        default = "/srv/tftp";
        example = "/var/lib/tftp";
        type = types.path;
        description = ''
          Document root directory for tftpd-hpa.

          Note that you must ensure that this directory exists and
          that it has the correct permissions; the service will not
          create it, not will it attempt to set its permissions.

          tftpd-hpa will be chroot'ed to this directory upon start-up.
          All tftp client paths will be relative to this directory.
        '';
      };

      listenAddress = mkOption {
        type = types.nullOr (types.either pkgs.lib.types.ipv4NoCIDR pkgs.lib.types.ipv6NoCIDR);
        default = null;
        example = "2001:db8::2";
        description = ''
          An optional IPv4 or IPv6 address on which the server will
          listen.

          The default is to listen on all local addresses.
        '';
      };

      extraOptions = mkOption {
        default = [ ];
        example = literalExample ''
          [ "--blocksize 1468" ]
        '';
        type = types.listOf pkgs.lib.types.nonEmptyStr;
        description = ''
          Extra command line arguments to pass to tftpd-hpa.

          The default value should be used in almost all cases.
        '';
      };

    };

  };

  config = mkIf cfg.enable {

    systemd.services.tftpd-hpa = {
      description = "hpa's original TFTP server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${pkgs.tftp-hpa}/bin/in.tftpd --listen ${addressOption} ${concatStringsSep " " cfg.extraOptions} --secure ${cfg.root}
      '';

      serviceConfig = {
        Type = "forking";
      };
    };

  };

  meta.maintainers = lib.maintainers.dhess-qx;

}
