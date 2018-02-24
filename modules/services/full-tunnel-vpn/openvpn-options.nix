# Limitations:
# - IPv4 netmask for clients is assumed to be 255.255.255.0. This is
#   because the NAT rules want a CIDR postfix (e.g., "/24") rather
#   than a netmask and I don't feel like writing a converter.

{ name, config, lib, pkgs }:

with lib;
rec {
  options = {

    name = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      default = "${name}";
      description = ''
        A short name for the OpenVPN instance. The name should be
        a valid <literal>systemd</literal> service name (i.e., no
        spaces, no special characters, etc.); the service that runs
        the instance will be named
        <literal>openvpn-<em>name</em>.service</literal>.

        If undefined, the name of the attribute set will be used.
      '';
    };

    port = mkOption {
      type = pkgs.lib.types.port;
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
      type = types.nonEmptyListOf (types.either pkgs.lib.types.ipv4NoCIDR pkgs.lib.types.ipv6NoCIDR);
      default = [ "8.8.8.8" "8.8.4.4" ];
      description = ''
        A list of DNS servers to be pushed to clients.
      '';
    };

    ipv4ClientBaseAddr = mkOption {
      type = pkgs.lib.types.ipv4NoCIDR;
      example = "10.0.1.0";
      description = ''
        The base of the IPv4 address range that will be used for
        clients. Do not provide a CIDR suffix.

        Note: the netmask for the range is always
        <literal>255.255.255.0</literal>, so you should assign
        <literal>/24</literal>s here.
      '';
    };

    ipv6ClientPrefix = mkOption {
      type = pkgs.lib.types.ipv6CIDR;
      example = "2001:db8::/32";
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

    certKeyLiteral = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      default = null;
      example = "<key>";
      description = ''
        The server's private key file, as a string literal. Note that
        this secret will not be copied to the Nix store. However, upon
        start-up, the service will copy a file containing the key to
        its persistent state directory.
      '';
    };

    crlFile = mkOption {
      type = types.path;
      description = ''
        A path to the CA's CRL file, for revoked certs.
      '';
    };

    tlsAuthKeyLiteral = mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      default = null;
      example = "<key>";
      description = ''
        The server's TLS auth key, as a string literal. Note that this
        secret will not be copied to the Nix store. However, upon
        start-up, the service will copy a file containing the key to
        its persistent state directory.
      '';
    };
  };
}
