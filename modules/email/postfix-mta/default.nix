## Generally speaking, my approach here is to name options by their
## actual Postfix name, so that the mapping between options specified
## here to what goes into the Postfix config file is clear. (With the
## NixOS option names, which are slightly different than the Postfix
## option names, I find that I have to dig through the postfix.nix file
## to figure out exactly what's going to be set to what.)

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.services.postfix-mta;
  enabled = cfg.enable;

  # NOTE - must be the same as upstream.
  stateDir = "/var/lib/postfix/data";
  queueDir = "/var/lib/postfix/queue";

  user = config.services.postfix.user;
  group = config.services.postfix.group;

in
{
  meta.maintainers = lib.maintainers.dhess-qx;

  options.services.postfix-mta = {

    enable = mkEnableOption ''
      A Postfix mail transfer agent (MTA), i.e., a host that can send
      and receive mail for one or more domains.

      Note that this particular configuration does <em>not</em>
      deliver mail to local storage. Mail that is received by this MTA
      (for the domains that it serves) is handed off to an MDA via
      LMTP+TLS over a TCP connection. This accommodates the decoupling
      of mail storage and IMAP hosts, which can often be locked down
      very tightly (e.g., only accessible on an internal network, or
      via VPN), from public mail transport hosts, which must be
      connected to the public Internet and communicate with untrusted
      hosts in order to be useful.

      Furthermore, this configuration will only accept mail relay from
      clients that authenticate via client certificates on the
      submission port.
    '';

    myDomain = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "example.com";
      description = ''
        Postfix's <literal>mydomain<literal> setting.
      '';
    };

    myDestination = mkOption {
      type = types.nonEmptyListOf pkgs.lib.types.nonEmptyStr;
      default = [
        "$myhostname"
        "localhost.$mydomain"
        "localhost"
        "$mydomain"
      ];
      example = literalExample [
        "$myhostname"
        "localhost.$mydomain"
        "localhost"
        "$mydomain"
        "another.local.tld"
      ];
      description = ''
        Postfix's <literal>mydestination</literal> setting.
      '';
    };

    myHostname = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "mx.example.com";
      description = ''
        Postfix's <literal>myhostname</literal> setting.

        Note that this setting is critical to reliable Internet mail
        delivery. It should be the same as the name specified in your
        domains' published TXT records for SPF, assuming you use
        <literal>a:</literal> notation in your TXT SPF records.
      '';
    };

    proxyInterfaces = mkOption {
      type = types.listOf pkgs.lib.types.nonEmptyStr;
      default = [];
      example = [ "192.0.2.1" ];
      description = ''
        Postfix's <literal>proxy_interfaces</literal> setting.
      '';
    };

    milters = {
      smtpd = mkOption {
        type = types.listOf pkgs.lib.types.nonEmptyStr;
        default = [];
        description = ''
          A list of smtpd milter sockets to use with the MTA.
        '';
      };

      nonSmtpd = mkOption {
        type = types.listOf pkgs.lib.types.nonEmptyStr;
        default = [];
        description = ''
          A list of non-smtpd milter sockets to use with the MTA.
        '';
      };
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Extra Postfix configuration.
      '';
    };
  };

  config = mkIf enabled {

    quixops.assertions.moduleHashes."services/mail/postfix.nix" =
      "f5fed80f255562040e51210d116f31b2b77241464ed7f09fe5c46c4e81b05681";

    services.postfix = {
      enable = true;
      domain = cfg.myDomain;
      origin = "$mydomain";
      destination = cfg.myDestination;
      hostname = cfg.myHostname;

      extraConfig =
      let
        proxy_interfaces = concatStringsSep " " cfg.proxyInterfaces;
        smtpd_milters = concatStringsSep " " cfg.milters.smtpd;
        non_smtpd_milters = concatStringsSep " " cfg.milters.nonSmtpd;
      in
      ''
        biff = no
        proxy_interfaces = ${proxy_interfaces}

        append_dot_mydomain = no
        mynetworks_style = host
        relay_domains =

        milter_default_action = accept
        smtpd_milters = ${smtpd_milters}
        non_smtpd_milters = ${non_smtpd_milters}
      '' + cfg.extraConfig;

    };

  };

}
