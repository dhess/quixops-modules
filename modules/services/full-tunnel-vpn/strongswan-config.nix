{ cfg, lib, pkgs, keys, ... }:

with lib;

let

  inherit (builtins) toFile;
  ikev2Port = 500;
  ikev2NatTPort = 4500;

  deployedCertKeyFile = keys.strongswan-cert-key.path;

  keyFile = "/var/lib/strongswan/key";

  strongSwanDns = concatMapStringsSep "," (x: "${x}") cfg.dns;

  secretsFile = toFile "strongswan.secrets"
    ": RSA ${keyFile}";
    
in
mkIf cfg.enable {

  assertions = [
    { assertion = pkgs.lib.exclusiveOr (cfg.certKeyFile == null) (cfg.certKeyLiteral == null);
      message = "In services.full-tunnel-vpn.strongswan, either certKeyFile or certKeyLiteral must be specified (but not both)";
    }
  ];

  quixops.assertions.moduleHashes."services/networking/strongswan.nix" =
        "55d1c76bcdb47d8c6ffe81bbcb9742b18e2c8d6aeb866f71959faed298ce7351";

  quixops.keychain.keys.strongswan-cert-key = {
    keyFile = cfg.certKeyFile;
    text = cfg.certKeyLiteral;
  };

  services.strongswan = {
    enable = true;
    secrets = [ secretsFile ];
    ca.strongswan = {
      auto = "add";
      cacert = "${cfg.caFile}";
      crlurl = "${cfg.crlFile}";
    };
    setup = { uniqueids = "never"; }; # Allow multiple connections by same cert.
    connections."%default" = {
      keyexchange = "ikev2";
      # Suite-B-GCM-256, Suite-B-GCM-128.
      ike = "aes256gcm16-prfsha384-ecp384,aes128gcm16-prfsha256-ecp256";
      esp = "aes256gcm16-prfsha384-ecp384,aes128gcm16-prfsha256-ecp256";
      fragmentation = "yes";
      dpdaction = "clear";
      dpddelay = "300s";
      rekey = "no";
      left = "%any";
      leftsubnet = "0.0.0.0/0,::/0";
      leftcert = "${cfg.certFile}";
      leftsendcert = "always";
      right = "%any";
      rightsourceip = "${cfg.ipv4ClientCidr}, ${cfg.ipv6ClientPrefix}";
      rightdns = "${strongSwanDns}";
      auto = "add";
    };
    connections."apple-roadwarrior" = {
      leftid = cfg.remoteId;
      auto = "add";
    };
  };
  
  networking.nat.internalIPs = [ cfg.ipv4ClientCidr ];
  networking.firewall.allowedUDPPorts = [ ikev2Port ikev2NatTPort ];

  systemd.services.strongswan-setup = {
    description = "strongswan setup script ";
    wantedBy = [ "multi-user.target" ];
    wants = [ "keys.target" ];
    after = [ "keys.target" ];
    requiredBy = [ "strongswan.service" ];
    before = [ "strongswan.service" ];
    script =
    ''
      install -m 0700 -o root -g root -d `dirname ${keyFile}` > /dev/null 2>&1 || true
      install -m 0400 -o root -g root ${deployedCertKeyFile} ${keyFile}
    '';
  };

}
