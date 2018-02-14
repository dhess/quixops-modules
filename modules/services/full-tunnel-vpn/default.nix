# An opinionated "full tunnel" VPN server; i.e., one intended to be
# used as the default route for clients.

{ config, pkgs, lib, ... }:

with lib;

let

  globalCfg = config.services.full-tunnel-vpn;
  enabled = globalCfg.openvpn != {};
  openvpnCfg = import ./openvpn-config.nix {
    inherit config lib;
    instances = globalCfg.openvpn;
  };

in
{

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

  config = mkIf enabled {

    networking.nat.enable = true;
    networking.nat.externalInterface = globalCfg.routedInterface;

    # In-tunnel IPv6 requires some tweaking.
    boot.kernel.sysctl = {
      "net.ipv6.conf.${globalCfg.routedInterface}.accept_ra" = 2;
      "net.ipv6.conf.all.forwarding" = 1;
      "net.ipv6.conf.${globalCfg.routedInterface}.proxy_ndp" = 1;
    };

    meta.maintainers = lib.maintainers.dhess-qx;

  }
  // openvpnCfg;
}