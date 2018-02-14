{ config, lib, instances, ... }:

with lib;

let

  stateDirBase = "/var/lib/openvpn";

  dns = cfg: concatMapStrings (x: "push \"dhcp-option DNS ${x}\"\n") cfg.dns;

  genConfig = cfg:
  let
    stateDir = "${stateDirBase}/${cfg.name}";
  in
  ''
    port ${toString cfg.port}
    proto ${cfg.proto}
    dev tun

    dh ${config.security.dhparams.path}/openvpn-${cfg.name}.pem
    ca ${cfg.caFile}
    cert ${cfg.certFile}
    key ${stateDir}/pki.key
    crl-verify ${cfg.crlFile}

    topology subnet
    server ${cfg.ipv4ClientBaseAddr} 255.255.255.0
    server-ipv6 ${cfg.ipv6ClientPrefix}
    route-ipv6 ${cfg.ipv6ClientPrefix}

    push "redirect-gateway ipv6 bypass-dhcp"
    ${dns cfg}
    push "route-ipv6 2000::/3"

    keepalive 10 120

    tls-auth ${stateDir}/tls-auth.key 0

    tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-GCM-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256:TLS-DHE-RSA-WITH-AES-256-CBC-SHA:TLS-DHE-RSA-WITH-AES-128-CBC-SHA
    cipher AES-256-CBC
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
    "1472c53fca590977bf0af94820eab36473ba5575519e752b825e295541e7ef8e";

  networking.nat.internalIPs =
    (mapAttrsToList
      (_: serverCfg: (
        "${serverCfg.ipv4ClientBaseAddr}/24"
       )) instances);

  networking.firewall.allowedUDPPorts =
    filter
      (x: x != null)
      (mapAttrsToList
        (_: cfg: if (cfg.proto == "udp" || cfg.proto == "udp6") then cfg.port else null)
        instances
      );
  networking.firewall.allowedTCPPorts =
    filter
      (x: x != null)
      (mapAttrsToList
        (_: cfg: if (cfg.proto == "tcp" || cfg.proto == "tcp6") then cfg.port else null)
        instances
      );


  # Note: it's not strictly necessary to use one dhparams per
  # server, but the nice thing about doing it this way is the the
  # dhparams-gen service will delay the start of our servers until
  # it's ready. (There is no single "openvpn.service" doing just the
  # one dhparams file for "openvpn" won't delay the start of the
  # individual server instances.)

  security.dhparams.enable = true;
  security.dhparams.params = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: serverCfg: nameValuePair "openvpn-${serverCfg.name}" serverCfg.dhparamsSize)
      ) instances)
    );

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
          in
          ''
            install -m 0750 -o openvpn -g openvpn -d ${stateDir} > /dev/null 2>&1 || true
            install -m 0400 -o openvpn -g openvpn ${serverCfg.certKeyFile} ${stateDir}/pki.key
            install -m 0400 -o openvpn -g openvpn ${serverCfg.tlsAuthKey} ${stateDir}/tls-auth.key
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
