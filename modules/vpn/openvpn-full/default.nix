# An opinionated "full tunnel" OpenVPN server; i.e., one intended to
# be used as the default route for clients.
#
# Limitations:
# - IPv4 netmask for clients is assumed to be 255.255.255.0. This is
#   because the NAT rules want a CIDR postfix (e.g., "/24") rather
#   than a netmask and I don't feel like writing a converter.

{ config, pkgs, lib, ... }:

with lib;

let

  globalCfg = config.services.openvpn-full;
  stateDirBase = "/var/lib/openvpn";

  dns = cfg: concatMapStrings (x: "push \"dhcp-option DNS ${x}\"\n") cfg.dns;

  genConfig = name: cfg:
  let
    stateDir = "${stateDirBase}/${name}";
  in
  ''
    port ${toString cfg.port}
    proto ${cfg.proto}
    dev tun

    dh ${config.security.dhparams.path}/openvpn-${name}.pem
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

  options.services.openvpn-full = {

    routedInterface = mkOption {
      type = types.string;
      example = "eth0";
      description = ''
        Traffic from all OpenVPN clients will be routed via this host
        interface.
      '';
    };
    
    servers = mkOption {
      type = types.attrsOf (types.submodule (
        { config, options, name, ... }:
        {
          options = {
          
            port = mkOption {
              type = types.int;
              example = 443;
              default = 1194;
              description = ''
                The port on which to run the OpenVPN service.
              '';
            };

            proto = mkOption {
              type = types.enum [ "udp" "tcp" "udp6" "tcp6" ];
              example = "tcp";
              default = "udp6";
              description = ''
                The OpenVPN transport protocol.
              '';
            };

            dns = mkOption {
              type = types.listOf types.string;
              default = [ "8.8.8.8" "8.8.4.4" ];
              description = ''
                A list of DNS servers to be pushed to clients.
              '';
            };

            ipv4ClientBaseAddr = mkOption {
              type = types.string;
              example = "10.0.1.0";
              description = ''
                The base of the IPv4 address range that will be used for
                clients.

                Note: the netmask for the range is always
                <literal>255.255.255.0</literal>, so you should assign
                <literal>/24</literal>s here.
              '';
            };

            ipv6ClientPrefix = mkOption {
              type = types.string;
              example = "2001:DB8::/32";
              description = ''
                The IPv6 prefix from which client IPv6 addresses will
                be assigned for this server.
              '';
            };

            caFile = mkOption {
              type = types.path;
              description = ''
                A path to the CA certificate used to authenticate client
                certificates for this server instance.
              '';
            };

            certFile = mkOption {
              type = types.path;
              description = ''
                A path to the OpenVPN public certificate for this
                server instance.
              '';
            };

            certKeyFile = mkOption {
              type = types.path;
              default = "/run/keys/openvpn-${name}-cert";
              description = ''
                A path to the server's private key. Note that this
                file will not be copied to the Nix store; the OpenVPN
                server will expect the file to be at the given path
                when it starts, so it must be deployed to the host
                out-of-band.

                The default value is
                <literal>/run/keys/openvpn-<replaceable>name</replaceable>-certkey</literal>,
                which is a NixOps <option>deployment.keys</option>
                path. If you use NixOps and you deploy the key to this
                default path, the OpenVPN server will automatically
                wait for that key to be present before it runs.

                Upon start-up, the service will copy the key to its
                persistent state directory.
              '';
            };

            crlFile = mkOption {
              type = types.path;
              description = ''
                A path to the CA's CRL file, for revoked certs.
              '';
            };

            tlsAuthKey = mkOption {
              type = types.path;
              default = "/run/keys/openvpn-${name}-tls-auth";
              description = ''
                A path to the server's TLS auth key. Note that this
                file will not be copied to the Nix store; the OpenVPN
                server will expect the file to be at the given path
                when it starts, so it must be deployed to the host
                out-of-band.

                The default value is
                <literal>/run/keys/openvpn-<replaceable>name</replaceable>-tls-auth</literal>,
                which is a NixOps <option>deployment.keys</option>
                path. If you use NixOps and you deploy the key to this
                default path, the OpenVPN server will automatically
                wait for that key to be present before it runs.

                Upon start-up, the service will copy the key to its
                persistent state directory.
              '';
            };

            dhparamsSize  = mkOption {
              type = types.int;
              default = 2048;
              description = ''
                The size (in bits) of the dhparams that will be
                generated for this OpenVPN instance.
              '';
            };
          };
        }
      ));
      default = {};
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

  config = mkIf (globalCfg.servers != {}) {

    quixops.assertions.moduleHashes."services/networking/openvpn.nix" =
      "1472c53fca590977bf0af94820eab36473ba5575519e752b825e295541e7ef8e";

    networking.nat.enable = true;
    networking.nat.externalInterface = globalCfg.routedInterface;
    networking.nat.internalIPs =
      (mapAttrsToList
        (serverName: serverCfg: (
          "${serverCfg.ipv4ClientBaseAddr}/24"
         )) globalCfg.servers);

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
        (serverName: serverCfg: nameValuePair "openvpn-${serverName}" serverCfg.dhparamsSize)
        ) globalCfg.servers)
      );

    services.openvpn.servers = listToAttrs (filter (x: x.value != null) (
      (mapAttrsToList
        (serverName: serverCfg: nameValuePair "${serverName}" ({
            config = genConfig serverName serverCfg;
          })) globalCfg.servers)
    ));

    systemd.services = listToAttrs (filter (x: x.value != null) (
      (mapAttrsToList
        (serverName: serverCfg: nameValuePair "openvpn-${serverName}-setup" (rec {
            description = "openvpn-${serverName} setup script ";
            wantedBy = [ "multi-user.target" ];
            wants = [ "keys.target" ];
            after = [ "keys.target" ];
            requiredBy = [ "openvpn-${serverName}.service" ];
            script =
            let
              stateDir = "${stateDirBase}/${serverName}";
            in
            ''
              install -m 0750 -o openvpn -g openvpn -d ${stateDir} > /dev/null 2>&1 || true
              install -m 0400 -o openvpn -g openvpn ${serverCfg.certKeyFile} ${stateDir}/pki.key
              install -m 0400 -o openvpn -g openvpn ${serverCfg.tlsAuthKey} ${stateDir}/tls-auth.key
            '';
          })) globalCfg.servers)
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
