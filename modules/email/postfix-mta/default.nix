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

  relay_clientcerts = pkgs.writeText "postfix-relay-clientcerts" cfg.relayClientCerts;

  bogus_mx = pkgs.writeText "postfix-bogus-mx" ''
    0.0.0.0/8              REJECT Domain MX in broadcast network (RFC 1700)
    10.0.0.0/8             REJECT No route to your network (RFC 1918)
    127.0.0.0/8            REJECT Domain MX in loopback network (RFC 5735)
    169.254.0.0/16         REJECT Domain MX in link local network (RFC 3927)
    172.16.0.0/12          REJECT No route to your network (RFC 1918)
    192.0.0.0/24           REJECT Domain MX in reserved IANA network (RFC 5735)
    192.0.2.0/24           REJECT Domain MX in TEST-NET-1 network (RFC 5737)
    192.168.0.0/16         REJECT No route to your network (RFC 1918)
    198.18.0.0/15          REJECT Domain MX reserved for network benchmark tests (RFC 2544)
    198.51.100.0/24        REJECT Domain MX in TEST-NET-2 network (RFC 5737)
    203.0.113.0/24         REJECT Domain MX in TEST-NET-3 network (RFC 5737)
    224.0.0.0/4            REJECT Domain MX in class D multicast network (RFC 3171)
    240.0.0.0/4            REJECT Domain MX in class E reserved network (RFC 1700)
  '';

  acmeRoot = "/var/lib/acme/acme-challenge";

in
{
  meta.maintainers = lib.maintainers.dhess-qx;

  options.services.postfix-mta = {

    enable = mkEnableOption ''
      A Postfix mail transfer agent (MTA), i.e., a host that can send
      and receive mail for one or more domains.

      Note that this particular configuration does not use Postfix to
      delivery deliver mail to local accounts. Mail that is received
      by this MTA (for the domains that it serves) is handed off to an
      MDA via Postfix's virtual_transport option. This accommodates
      the decoupling of mail storage and IMAP hosts, which can often
      be locked down very tightly (e.g., only accessible on an
      internal network, or via VPN), from public mail transport hosts,
      which must be connected to the public Internet and communicate
      with untrusted hosts in order to be useful.

      Furthermore, this configuration will only accept mail relay from
      clients that authenticate via client certificates on the
      submission port.

      For this service to work, you must open TCP ports 25 and 587 for
      the SMTP and submission protocols; and 80 and 443 for ACME
      TLS certificate provisioning.
    '';

    myDomain = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "example.com";
      description = ''
        Postfix's <literal>mydomain<literal> setting.
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

    recipientDelimiter = mkOption {
      type = types.str;
      default = "+";
      example = "+-";
      description = ''
        Postfix's <literal>recipient_delimiter</literal> setting.
      '';
    };

    relayClientCerts = mkOption {
      type = types.lines;
      default = "";
      example = literalExample ''
        D7:04:2F:A7:0B:8C:A5:21:FA:31:77:E1:41:8A:EE:80 lutzpc.at.home
      '';
      description = ''
        A series of client certificate SHA1 fingerprints, one per
        line, as used by by Postfix's
        <literal>relay_clientcerts</literal> setting.

        These fingerprints are consulted wherever the Postfix
        configuration uses the
        <literal>permit_tls_clientcerts</literal> feature. In the
        default <literal>postfix-mta</literal> service configuration,
        this is used by the <option>smtpd.clientRestrictions</option>
        option.

        If you don't use client certificates, just leave this option
        as the default value.
      '';
    };

    smtpd = {
      clientRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);
        default = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "permit_tls_clientcerts"
          "reject_unknown_reverse_client_hostname"
        ];
        example = literalExample [
          "permit_mynetworks"
          "reject_unknown_client_hostname"
        ];
        description = ''
          Postfix's <literal>smtpd_client_restrictions</literal> setting.

          If null, Postfix's default value will be used.
        '';
      };

      heloRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);
        # XXXX TODO dhess - add helo_checks for our own MXes.
        default = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "permit_tls_clientcerts"
          "reject_unknown_helo_hostname"
        ];
        example = literalExample [
          "permit_mynetworks"
          "reject_invalid_helo_hostname"
        ];
        description = ''
          Postfix's <literal>smtpd_helo_restrictions</literal> setting.

          If null, Postfix's default value will be used.
        '';
      };

      senderRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);
        default = [
          "reject_non_fqdn_sender"
          "reject_unknown_sender_domain"
          "check_sender_mx_access hash:/etc/postfix/bogus_mx"
        ];
        example = literalExample [
          "permit_mynetworks"
          "reject_invalid_helo_hostname"
        ];
        description = ''
          Postfix's <literal>smtpd_sender_restrictions</literal> setting.

          If null, Postfix's default value will be used.
        '';
      };

      relayRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);
        default = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "permit_tls_clientcerts"
          "reject_non_fqdn_recipient"
          "reject_unauth_destination"
        ];
        example = literalExample [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "defer_unauth_destination"
        ];
        description = ''
          Postfix's <literal>smtpd_relay_restrictions</literal> setting.

          If null, Postfix's default value will be used.

          Note that either this option or
          <option>recipientRestrictions</option> must specify certain
          restrictions, or else Postfix will refuse to deliver mail.
          See the Postfix documentation for details. (The default
          values of these options satisfy the requirements.)
        '';
      };

      recipientRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);

        # XXX TODO dhess - add check_recipient_access with roleaccount_exceptions.
        default = [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "permit_tls_clientcerts"
          "reject_unknown_recipient_domain"
          "reject_unverified_recipient"
        ];
        example = literalExample [
          "permit_mynetworks"
          "permit_sasl_authenticated"
          "defer_unauth_destination"
        ];
        description = ''
          Postfix's <literal>smtpd_recipient_restrictions</literal> setting.

          If null, Postfix's default value will be used.

          Note that many Postfix guides recommend using RBL/DNSBL
          checks here; by default, we do not, because we assume that a
          milter such as rspamd will be used, and those generally do a
          better/more comprehensive job.

          Note also that either this option or
          <option>relayRestrictions</option> must specify certain
          restrictions, or else Postfix will refuse to deliver mail.
          See the Postfix documentation for details. (The default
          values of these options satisfy the requirements.)
        '';
      };

      dataRestrictions = mkOption {
        type = types.nullOr (types.listOf pkgs.lib.types.nonEmptyStr);
        default = [
          "reject_unauth_pipelining"
        ];
        example = literalExample [
          "reject_multi_recipient_bounce"
        ];
        description = ''
          Postfix's <literal>smtpd_data_restrictions</literal> setting.

          If null, Postfix's default value will be used.
        '';
      };
    };

    virtual = {
      transport = mkOption {
        type = pkgs.lib.types.nonEmptyStr;
        example = "lmtp:hostname:port";
        description = ''
          Postfix's <literal>virtual_transport</literal> setting.
        '';
      };

      mailboxDomains = mkOption {
        type = types.nonEmptyListOf pkgs.lib.types.nonEmptyStr;
        default = [
          "$mydomain"
        ];
        example = literalExample [
          "$mydomain"
          "another.local.tld"
        ];
        description = ''
          Postfix's <literal>virtual_mailbox_domains</literal> setting.
        '';
      };

      aliasDomains = mkOption {
        type = types.nonEmptyListOf pkgs.lib.types.nonEmptyStr;
        default = [];
        example = literalExample [
          "another.local.tld"
        ];
        description = ''
          Postfix's <literal>virtual_alias_domains</literal> setting.
        '';
      };

      aliasMaps = mkOption {
        type = types.lines;
        default = "";
        description = ''
          Entries for the Postfix's <literal>virtual_alias_maps</literal> file.
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
    quixops.assertions.moduleHashes."security/acme.nix" =
      "d87bf3fddbdcd3c42f5ba8d543c6b1680d3797fad8403d4c073af6cdb5278997";


    # This Nginx vhost exists only to provision ACME certs for the
    # Postfix MTA.

    services.nginx = {
      enable = true;
      virtualHosts."${cfg.myHostname}" = {
        forceSSL = true;
        useACMEHost = "${cfg.myHostname}";
        locations."/" = {
          root = acmeRoot;
        };
      };
    };


    # If this MX is configured correctly, we only need the ACME cert
    # for myhostname, as that's the name that it'll be reporting both
    # to SMTP clients (upon mail receipt) and to SMTP servers (upon
    # mail delivery). In other words, we don't need to add any virtual
    # domains to the ACME extraDomains.

    security.acme.certs."${cfg.myHostname}" = {
      webroot = acmeRoot;
      email = "postmaster@${cfg.myDomain}";
      allowKeysForGroup = true;
      inherit group;
      postRun = ''
        systemctl reload postfix
        systemctl reload nginx
      '';
    };


    services.postfix = {
      enable = true;
      domain = cfg.myDomain;
      origin = "$mydomain";
      hostname = cfg.myHostname;

      recipientDelimiter = cfg.recipientDelimiter;

      # Disable Postfix delivery; all delivery goes through the
      # virtual transport.

      destination = [ "" ];

      virtual = cfg.virtual.aliasMaps;

      mapFiles = {
        "relay_clientcerts" = relay_clientcerts;
        "bogus_mx" = bogus_mx;
      };

      extraConfig =
      let
        proxy_interfaces = concatStringsSep ", " cfg.proxyInterfaces;
        smtpd_milters = concatStringsSep ", " cfg.milters.smtpd;
        non_smtpd_milters = concatStringsSep ", " cfg.milters.nonSmtpd;
        virtual_mailbox_domains = concatStringsSep ", " cfg.virtual.mailboxDomains;
        virtual_alias_domains = concatStringsSep ", " cfg.virtual.aliasDomains;
        smtpd_client_restrictions = optionalString (cfg.smtpd.clientRestrictions != null)
          ("smtpd_client_restrictions = " + (concatStringsSep ", " cfg.smtpd.clientRestrictions));
        smtpd_helo_restrictions = optionalString (cfg.smtpd.heloRestrictions != null)
          ("smtpd_helo_restrictions = " + (concatStringsSep ", " cfg.smtpd.heloRestrictions) +
          (optionalString (cfg.smtpd.heloRestrictions != []) "\nsmtpd_helo_required = yes"));
        smtpd_sender_restrictions = optionalString (cfg.smtpd.senderRestrictions != null)
          ("smtpd_sender_restrictions = " + (concatStringsSep ", " cfg.smtpd.senderRestrictions));
        smtpd_relay_restrictions = optionalString (cfg.smtpd.relayRestrictions != null)
          ("smtpd_relay_restrictions = " + (concatStringsSep ", " cfg.smtpd.relayRestrictions));
        smtpd_recipient_restrictions = optionalString (cfg.smtpd.recipientRestrictions != null)
          ("smtpd_recipient_restrictions = " + (concatStringsSep ", " cfg.smtpd.recipientRestrictions));
        smtpd_data_restrictions = optionalString (cfg.smtpd.dataRestrictions != null)
          ("smtpd_data_restrictions = " + (concatStringsSep ", " cfg.smtpd.dataRestrictions));
      in
      ''
        biff = no
        proxy_interfaces = ${proxy_interfaces}

        append_dot_mydomain = no
        remote_header_rewrite_domain = domain.invalid

        mynetworks_style = host
        relay_domains =

        milter_default_action = accept
        smtpd_milters = ${smtpd_milters}
        non_smtpd_milters = ${non_smtpd_milters}

        virtual_transport = ${cfg.virtual.transport}
        virtual_mailbox_domains = ${virtual_mailbox_domains}
        virtual_alias_domains = ${virtual_alias_domains}

        relay_clientcerts = hash:/etc/postfix/relay_clientcerts
        smtpd_tls_fingerprint_digest = sha1

        ${smtpd_client_restrictions}
        ${smtpd_helo_restrictions}
        ${smtpd_sender_restrictions}
        ${smtpd_relay_restrictions}
        ${smtpd_recipient_restrictions}
        ${smtpd_data_restrictions}

        unverified_recipient_reject_reason = Address lookup failed
      '' + cfg.extraConfig;

    };

  };

}
