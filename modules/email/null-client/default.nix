## Configuration for what Postfix calls a "null client," i.e., a host
## that can only send mail to another host. This configuration
## enforces an encrypted transport from the client to the relay host.

# Generally speaking, my approach here is to name options by their
# actual Postfix name, so that the mapping between options specified
# here to what goes into the Postfix config file is clear. (With the
# NixOS option names, which are slightly different than the Postfix
# option names, I find that I have to dig through the postfix.nix file
# to figure out exactly what's going to be set to what.)

{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.services.postfix-null-client;
  enabled = cfg.enable;

  user = config.services.postfix.user;
  group = config.services.postfix.group;
  keyFileName = "${cfg.stateDir}/null-client.key";
  deployedKeyFile = config.quixops.keychain.keys.postfix-null-client-cert-key.path;

in
{
  options.services.postfix-null-client = {

    enable = mkEnableOption ''
      A Postfix null client, i.e., a client that can only send mail.
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

    relayHost = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      example = "mail.example.com";
      description = ''
        The hostname portion of Postfix's <literal>relayhost</literal>
        setting.
      '';
    };

    relayPort = mkOption {
      type = pkgs.lib.types.port;
      default = 587;
      example = 25;
      description = ''
        The port number portion of Postfix's
        <literal>relayhost</literal> setting.
      '';
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
        The null client's private key file, as a string literal. Note
        that this secret will not be copied to the Nix store. However,
        upon start-up, the service will copy a file containing the key
        to its persistent state directory.
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "/var/lib/postfix-null-client";
      example = "/var/lib/postfix";
      description = ''
        Where the service stores the file containing the client's
        private key file.
      '';
    };

  };

  config = mkIf enabled {

    quixops.assertions.moduleHashes."services/mail/postfix.nix" =
      "4bd84b1e40118e4f1822376945b3405797d9c41fc1ca8d12373daa737130af32";

    quixops.keychain.keys.postfix-null-client-cert-key = {
      text = cfg.smtpTlsKeyLiteral;
    };

    services.postfix = {
      enable = true;

      domain = cfg.myDomain;
      origin = cfg.myOrigin;

      # See
      # http://www.postfix.org/STANDARD_CONFIGURATION_README.html#null_client
      destination = [ "" ];

      relayHost = cfg.relayHost;
      relayPort = cfg.relayPort;

      sslCACert = "${cfg.smtpTlsCAFile}";
      sslCert = "${cfg.smtpTlsCertFile}";
      sslKey = keyFileName;

      extraConfig = ''

        ##
        ## postfix-null-client.nix extraConfig begins here.

        biff = no

        # appending .domain is the MUA's job.
        append_dot_mydomain = no

        inet_interfaces = loopback-only
        local_transport = error:local delivery is disabled

        smtp_tls_security_level = encrypt
      '';
    };

    systemd.services.postfix-null-client-setup = {
      description = "Postfix null client setup script";
      wantedBy = [ "multi-user.target" ];
      wants = [ "keys.target" ];
      after = [ "keys.target" ];
      requiredBy = [ "postfix.service" ];
      before = [ "postfix.service" ];
      script = ''
        install -m 0700 -o ${user} -g ${group} -d ${cfg.stateDir} > /dev/null 2>&1 || true
        install -m 0400 -o ${user} -g ${group} ${deployedKeyFile} ${keyFileName}
      '';
    };

    meta.maintainers = lib.maintainers.dhess-qx;
  };
}
