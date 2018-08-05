{ config, lib, pkgs, instances, ... }:

with lib;

let

  stateDirBase = "/var/lib/openvpn";
  keychain = config.quixops.keychain.keys;

  dns = cfg: concatMapStrings (x: "push \"dhcp-option DNS ${x}\"\n") cfg.dns;

  genConfig = cfg:
  let
    stateDir = "${stateDirBase}/${cfg.name}";
    ipv4ClientBase = pkgs.lib.ipaddr.ipv4AddrFromCIDR cfg.ipv4ClientSubnet;
    netmask = pkgs.lib.ipaddr.netmaskFromIPv4CIDR cfg.ipv4ClientSubnet;
  in
  ''
    port ${toString cfg.port}
    proto ${cfg.proto}
    dev tun

    dh ${pkgs.lib.security.ffdhe3072Pem}
    ca ${cfg.caFile}
    cert ${cfg.certFile}
    key ${stateDir}/pki.key
    crl-verify ${cfg.crlFile}

    topology subnet
    server ${ipv4ClientBase} ${netmask}
    server-ipv6 ${cfg.ipv6ClientPrefix}
    route-ipv6 ${cfg.ipv6ClientPrefix}

    push "redirect-gateway ipv6 bypass-dhcp"
    ${dns cfg}
    push "route-ipv6 2000::/3"

    keepalive 10 120

    tls-auth ${stateDir}/tls-auth.key 0

    tls-cipher TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-GCM-SHA384
    cipher AES-128-GCM
    ecdh-curve secp384r1
    comp-lzo

    user openvpn
    group openvpn

    persist-tun
    persist-key

    duplicate-cn

    replay-persist ${stateDir}/replays.db

    status ${stateDir}/status.log
    verb 4
    mute-replay-warnings
  '';

in
mkIf (instances != {}) {

  quixops.assertions.moduleHashes."services/networking/openvpn.nix" =
    "ddc549a7f879306b31d88f2af1aba79da33d2d8f6f8e4a4c37af0d138e005403";

  quixops.keychain.keys = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: serverCfg: nameValuePair "openvpn-${serverCfg.name}-cert-key" ({
        text = serverCfg.certKeyLiteral;
      })) instances) ++
    (mapAttrsToList
      (_: serverCfg: nameValuePair "openvpn-${serverCfg.name}-tls-auth-key" ({
        text = serverCfg.tlsAuthKeyLiteral;
      })) instances)
  ));

  networking.nat.internalIPs =
    (mapAttrsToList
      (_: serverCfg: (
        "${serverCfg.ipv4ClientSubnet}"
       )) instances);

  services.openvpn.servers = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: serverCfg: nameValuePair "${serverCfg.name}" ({
          config = genConfig serverCfg;
        })) instances)
  ));

  systemd.services = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: serverCfg: nameValuePair "openvpn-${serverCfg.name}-setup" (rec {
          description = "openvpn-${serverCfg.name} setup script ";
          wantedBy = [ "multi-user.target" ];
          wants = [ "keys.target" ];
          after = [ "keys.target" ];
          requiredBy = [ "openvpn-${serverCfg.name}.service" ];
          script =
          let
            stateDir = "${stateDirBase}/${serverCfg.name}";
            deployedCertKey = keychain."openvpn-${serverCfg.name}-cert-key".path;
            deployedTLSAuthKey = keychain."openvpn-${serverCfg.name}-tls-auth-key".path;
          in
          ''
            install -m 0750 -o openvpn -g openvpn -d ${stateDir} > /dev/null 2>&1 || true
            install -m 0400 -o openvpn -g openvpn ${deployedCertKey} ${stateDir}/pki.key
            install -m 0400 -o openvpn -g openvpn ${deployedTLSAuthKey} ${stateDir}/tls-auth.key
          '';
        })) instances)
  ));

  users.users.openvpn = {
    description = "openvpn user";
    name = "openvpn";
    group = "openvpn";
    isSystemUser = true;          
  };
  users.extraGroups.openvpn.name = "openvpn";
}
