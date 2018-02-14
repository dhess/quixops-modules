{ name, config, lib }:

with lib;
rec {
  options = {

    name = mkOption {
      type = types.string;
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
