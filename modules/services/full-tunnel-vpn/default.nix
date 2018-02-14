# An opinionated "full tunnel" VPN server; i.e., one intended to be
# used as the default route for clients.
#
# Limitations:
# - IPv4 netmask for clients is assumed to be 255.255.255.0. This is
#   because the NAT rules want a CIDR postfix (e.g., "/24") rather
#   than a netmask and I don't feel like writing a converter.

{ config, pkgs, lib, ... }:

with lib;

let

  globalCfg = config.services.full-tunnel-vpn;
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

in {

  options.services.full-tunnel-vpn = {

    routedInterface = mkOption {
      type = types.string;
      example = "eth0";
      description = ''
        Traffic from all VPN clients will be routed via this host
        interface.
      '';
    };
    
    openvpn = mkOption {
      type = types.attrsOf (types.submodule ({ name, ... }: (import ./openvpn-options.nix {
        inherit name config lib;
      })));
      default = {};
      example = literalExample ''
        vpn1 = {
          ipv4ClientBaseAddr = "10.0.0.0";
          ipv6ClientPrefix = "2001:db8::/64";
          caFile = ./root.crt;
          certFile = ./vpn1.crt;
          certKeyFile = "/run/keys/vpn1.key";
          crlFile = ./root.crl;
          tlsAuthKey = "/run/keys/vpn1-tls-auth.key";
        };
      '';
      description = ''
        Declarative OpenVPN "full-tunnel" server instances. Each server
        appears as a service
        <literal>openvpn-<replaceable>name</replaceable></literal> on
        the host system, so that it can be started and stopped via
        <command>systemctl</command>.

        IPv4 traffic that is routed to a full-tunnel OpenVPN server will
        be NATed to the server's public IPv4 address. IPv6 traffic will
        be routed normally and clients will be given a public IPv6
        address from the pool assigned to the OpenVPN server.
      '';
      };
  };

  config = mkIf (globalCfg.openvpn != {}) {

    quixops.assertions.moduleHashes."services/networking/openvpn.nix" =
      "1472c53fca590977bf0af94820eab36473ba5575519e752b825e295541e7ef8e";

    networking.nat.enable = true;
    networking.nat.externalInterface = globalCfg.routedInterface;
    networking.nat.internalIPs =
      (mapAttrsToList
        (_: serverCfg: (
          "${serverCfg.ipv4ClientBaseAddr}/24"
         )) globalCfg.openvpn);

    networking.firewall.allowedUDPPorts =
      filter
        (x: x != null)
        (mapAttrsToList
          (_: cfg: if (cfg.proto == "udp" || cfg.proto == "udp6") then cfg.port else null)
          globalCfg.openvpn
        );
    networking.firewall.allowedTCPPorts =
      filter
        (x: x != null)
        (mapAttrsToList
          (_: cfg: if (cfg.proto == "tcp" || cfg.proto == "tcp6") then cfg.port else null)
          globalCfg.openvpn
        );

    # In-tunnel IPv6 requires some tweaking.
    boot.kernel.sysctl = {
      "net.ipv6.conf.${globalCfg.routedInterface}.accept_ra" = 2;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.${globalCfg.routedInterface}.proxy_ndp" = 1;
    };


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
        ) globalCfg.openvpn)
      );

    services.openvpn.servers = listToAttrs (filter (x: x.value != null) (
      (mapAttrsToList
        (_: serverCfg: nameValuePair "${serverCfg.name}" ({
            config = genConfig serverCfg;
          })) globalCfg.openvpn)
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
          })) globalCfg.openvpn)
    ));

    users.users.openvpn = {
      description = "openvpn user";
      name = "openvpn";
      group = "openvpn";
      isSystemUser = true;          
    };
    users.extraGroups.openvpn.name = "openvpn";

    meta.maintainers = lib.maintainers.dhess-qx;

  };
}
