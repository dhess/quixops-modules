## Configuration for an opinionated, anycast Postfix relay host, i.e.,
## a host that can send mail *to a prescribed set of domains* on
## behalf of other hosts. One typical use for such a service is to
## support oddball hardware (e.g., a UPS) that can send email, but not
## securely; or to limit outbound SMTP access to a limited number of
## hosts that run the relay service.
##
## This configuration will listen on the specified anycast addresses
## and will open local firewall ports on 25 and 587.

# Generally speaking, my approach here is to name options by their
# actual Postfix name, so that the mapping between options specified
# here to what goes into the Postfix config file is clear. (With the
# NixOS option names, which are slightly different than the Postfix
# option names, I find that I have to dig through the postfix.nix file
# to figure out exactly what's going to be set to what.)

# TODO
# - add allowedIPs and firewall config
# - run smtpd and submission only on anycast addresses
# - client cert fingerprints

{ config, pkgs, lib, ... }:

with lib;

let

  globalCfg = config;
  cfg = config.services.postfix-relay-host;
  enabled = cfg.enable;
  stateDir = "/var/lib/postfix-relay-host";

  user = config.services.postfix.user;
  group = config.services.postfix.group;
  keyFileName = "${stateDir}/relay-host.key";
  deployedKeyFile = config.quixops.keychain.keys.postfix-relay-host-cert-key.path;

  v4interfaces =
    concatMapStringsSep " " (o:
      "${o.addrOpts.address}"
    ) cfg.anycastAddrs.v4;
  v6interfaces =
    concatMapStringsSep " " (o:
      "[${o.addrOpts.address}]"
    ) cfg.anycastAddrs.v6;

in
{
  options.services.postfix-relay-host = {

    enable = mkEnableOption ''
      A Postfix relay host, i.e., a host that can send email to a
      <em>prescribed set of domains</em> on behalf of other hosts.

      <strong>Do not</strong> run this service on an untrusted
      network, e.g., on the public Internet. It configures Postfix to
      accept mail from any host as long as the recipient address is in
      the prescribed set of relay domains. Tthe consequences of a
      rogue mail agent using this service are less severe than they
      would be on a full mailhost, since only recipients in the set of
      relay domains could be spammed by such an agent; but it would
      still be detrimental to recipients in the relay domains.

      This configuration enforces a high-security encrypted transport
      from this host to the remote relay host. This requires trusted
      TLS certificates and the requisite TLS configuration on the
      remote relay host.

      Clients of this relay host are given a bit more leeway, given
      that many SMTP-enabled devices have poor SMTP client
      implementations for which secure configurations may not be
      practical, or even possible. Therefore, the preferred way to
      connect to this relay host service is via port 587 with client
      certificate authorization (using a pre-computed fingerprint),
      but clients that are not capable of this are allowed to connect
      with a plaintext connection over port 25.

      This configuration will listen on one or more specified anycast
      addresses and will open local TCP firewall ports on 25 and 587.
      You can optionally provide a list of IPs that are permitted to
      connect to these anycast IP/port combinations, in which case all
      other IPs will be blocked by the local firewall configuration
      (assuming the firewall is enabled in the host's config).

    '';

    myDomain = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "example.com";
      description = ''
        Postfix's <literal>mydomain<literal> setting.
      '';
    };

    myOrigin = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "example.com";
      description = ''
        Postfix's <literal>myorigin</literal> setting. On Debian
        systems, this comes from <literal>/etc/mailname</literal>.
      '';
    };

    masqueradeDomains = mkOption {
      type = types.nullOr (types.nonEmptyListOf pkgs.lib.types.nonEmptyStr);
      default = null;
      example = [ "foo.example.com" "example.com" ];
      description = ''
        Strip leading subdomain structure from outgoing email
        addresses. In the example given,
        <literal>bob@vader.foo.example.com</literal> becomes
        <literal>bob@foo.example.com</literal>, and
        <literal>alice@bar.example.com</literal> becomes
        <literal>alice@example.com</literal>.

        This is useful with broken mailers that insist on using their
        FQDN (e.g., OpenBSD).
      '';
    };

    relayDomains = mkOption {
      type = types.listOf pkgs.lib.types.nonEmptyStr;
      default = [];
      example = [ "example.com" "example.net" ];
      description = ''
        A list of domains for which this Postfix service will accept
        RCPT TO requests, i.e., for which it will accept and relay
        mail.

        If you want to accept mail for a domain's subdomains as well
        (e.g., for <literal>example.com</literal> as well as
        <literal>*.example.com</literal>), it's best to specify both
        <literal>example.com</literal> and
        <literal>.example.com</literal>, for future-proofing. (In the
        future, Postfix will require the latter convention.)
      '';
    };

    relayHost = mkOption {
      type = types.str;
      default = "";
      description = "
        Mail relay for outbound mail.
      ";
    };

    relayPort = mkOption {
      type = types.int;
      default = 25;
      description = "
        SMTP port for relay mail relay.
      ";
    };

    lookupMX = mkOption {
      type = types.bool;
      default = false;
      description = "
        Whether relay specified is just domain whose MX must be used.
      ";
    };

    smtpTlsCAFile = mkOption {
      type = types.path;
      description = ''
        A path to the CA certificate to be used to authenticate SMTP
        connections.
      '';
    };

    smtpTlsCertFile = mkOption {
      type = types.path;
      description = ''
        A path to the client certificate to be used to authenticate
        SMTP client connections.
      '';
    };

    smtpTlsKeyLiteral = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "<key>";
      description = ''
        The relay host's private key file, as a string literal. Note
        that this secret will not be copied to the Nix store. However,
        upon start-up, the service will copy a file containing the key
        to its persistent state directory.
      '';
    };

    anycastAddrs = mkOption {
      type = pkgs.lib.types.anycastAddrs;
      default = { v4 = []; v6 = []; };
      example = {
        v4 = [ { ifnum = 0; addrOpts = { address = "10.8.8.8"; prefixLength = 32; }; } ];
        v6 = [ { ifnum = 0; addrOpts = { address = "2001:db8::1"; prefixLength = 128; }; } ];
      };
      description = ''
        A set of IPv4 and IPv6 anycast addresses on which the
        Postfix relay host will listen.
      '';
    };

  };

  config = mkIf enabled {

    quixops.assertions.moduleHashes."services/mail/postfix.nix" =
      "4bd84b1e40118e4f1822376945b3405797d9c41fc1ca8d12373daa737130af32";

    quixops.keychain.keys.postfix-relay-host-cert-key = {
      text = cfg.smtpTlsKeyLiteral;
    };

    assertions = [
      { assertion = !globalCfg.services.postfix-null-client.enable;
        message = "Only one of `services.postfix-null-client` and `services.postfix-relay-host` can be set";
      }
      { assertion = (cfg.anycastAddrs.v4 == [] -> cfg.anycastAddrs.v6 != []) &&
                    (cfg.anycastAddrs.v6 == [] -> cfg.anycastAddrs.v4 != []);
        message = "At least one anycast address must be set in `services.postfix-relay-host`";
      }
    ];

    networking.anycastAddrs = cfg.anycastAddrs;
    networking.firewall.allowedTCPPorts = [ 25 587 ];

    services.postfix = {
      enable = true;

      domain = cfg.myDomain;
      origin = cfg.myOrigin;

      # Disable local delivery.
      destination = [ "" ];

      relayDomains = cfg.relayDomains;

      relayHost = cfg.relayHost;
      relayPort = cfg.relayPort;
      lookupMX = cfg.lookupMX;

      sslCACert = "${cfg.smtpTlsCAFile}";
      sslCert = "${cfg.smtpTlsCertFile}";
      sslKey = keyFileName;

      extraConfig = ''

        ##
        ## postfix-relay-host.nix extraConfig begins here.

        biff = no

        # appending .domain is the MUA's job.
        append_dot_mydomain = no

        local_transport = error:local delivery is disabled

        ${optionalString (cfg.masqueradeDomains != null) ''
          masquerade_domains = ${concatStringsSep " " cfg.masqueradeDomains}
          masquerade_classes = envelope_sender, envelope_recipient, header_sender, header_recipient
        ''}

        smtpd_tls_security_level = may
        smtpd_tls_session_cache_database = btree:${stateDir}/smtpd_scache
        smtpd_tls_loglevel=1
        smtpd_tls_auth_only = yes
        smtpd_tls_ask_ccert = yes
        smtpd_tls_fingerprint_digest = sha1
        smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3
        smtpd_tls_dh1024_param_file = ${pkgs.lib.security.ffdhe3072Pem};
        smtpd_tls_eecdh_grade = strong
        smtpd_tls_received_header = yes
        smtpd_relay_restrictions = permit_auth_destination reject

        smtp_tls_session_cache_database = btree:${stateDir}/smtp_scache
        smtp_tls_security_level = encrypt
        smtp_tls_mandatory_protocols = !SSLv2, !SSLv3
        smtp_tls_mandatory_ciphers = high
      '';
    };

    systemd.services.postfix-relay-host-setup = {
      description = "Postfix relay host setup script";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" ];
      requiredBy = [ "postfix.service" ];
      before = [ "postfix.service" ];
      script = ''
        install -m 0700 -o ${user} -g ${group} -d ${stateDir} > /dev/null 2>&1 || true
        install -m 0400 -o ${user} -g ${group} ${deployedKeyFile} ${keyFileName}
      '';
    };

    meta.maintainers = lib.maintainers.dhess-qx;
  };
}