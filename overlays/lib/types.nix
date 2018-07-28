## Additional useful types, mostly for NixOS modules.

# The key type defined here is based on keyOptionType in NixOps. As it
# is a derivative work of NixOps, it is covered by the GNU LGPL; see
# the LICENSE file included with this source distribution.

{ lib
, pkgs
, ...
}:

with lib;

rec {
  ## A key type for configuring secrets that are stored in the
  ## filesystem. The option names and types here are compatible with
  ## NixOps's `keyType`, so they can be mechanically mapped to
  ## `deployment.keys`, but there are a few differences; namely, this
  ## type ensures that its paths are not contained in the Nix store,
  ## so that the chances of accidentally storing a secret in the store
  ## are minimized.

  key = types.submodule ({ config, name, ... }: {
    options.text = mkOption {
      example = "super secret stuff";
      type = pkgs.lib.types.nonEmptyStr;
      description = ''
        This designates the text that the key should contain. So if
        the key name is <replaceable>password</replaceable> and
        <literal>foobar</literal> is set here, the contents of the
        file
        <filename><replaceable>destDir</replaceable>/<replaceable>password</replaceable></filename>
        will be <literal>foobar</literal>.
      '';
    };

    options.destDir = mkOption {
      default = "/run/keys";
      type = pkgs.lib.types.nonStorePath;
      description = ''
        When specified, this allows changing the destDir directory of the key
        file from its default value of <filename>/run/keys</filename>.

        This directory will be created, its permissions changed to
        <literal>0750</literal> and ownership to <literal>root:keys</literal>.
      '';
    };

    options.path = mkOption {
      type = pkgs.lib.types.nonStorePath;
      default = "${config.destDir}/${name}";
      internal = true;
      description = ''
        Path to the destination of the file, a shortcut to
        <literal>destDir</literal> + / + <literal>name</literal>

        Example: For key named <literal>foo</literal>,
        this option would have the value <literal>/run/keys/foo</literal>.
      '';
    };

    options.user = mkOption {
      default = "root";
      type = pkgs.lib.types.nonEmptyStr;
      description = ''
        The user which will be the owner of the key file.
      '';
    };

    options.group = mkOption {
      default = "root";
      type = pkgs.lib.types.nonEmptyStr;
      description = ''
        The group that will be set for the key file.
      '';
    };

    options.permissions = mkOption {
      default = "0400";
      example = "0640";
      type = pkgs.lib.types.nonEmptyStr;
      description = ''
        The default permissions to set for the key file, needs to be in the
        format accepted by <citerefentry><refentrytitle>chmod</refentrytitle>
        <manvolnum>1</manvolnum></citerefentry>.
      '';
    };
  });


  allowedIPs = types.listOf (types.submodule {
    options = {

      protocol = mkOption {
        type = types.enum [ "udp" "tcp" ];
        example = "tcp";
        description = "The protocol namespace of <option>port</option>.";
      };

      port = mkOption {
        type = types.either pkgs.lib.types.port (types.strMatching "[[:digit:]]+:[[:digit:]]+");
        example = "8000:8007";
        description = ''
          The local (destination) port number, or colon-delimited port number range.
        '';
      };

      sourcePort = mkOption {
        type = types.nullOr (types.either pkgs.lib.types.port (types.strMatching "[[:digit:]]+:[[:digit:]]+"));
        default = null;
        example = "67:68";
        description = ''
          An optional source port number, or colon-delimited port
          number range, to filter on. If non-null, an additional
          filter will be applied using the provided source port
          number.

          This is helpful for securing certain protocols, e.g., DHCP.
        '';
      };

      interface = mkOption {
        type = types.nullOr pkgs.lib.types.nonEmptyStr;
        default = null;
        example = "eth0";
        description = ''
          An optional device interface name. If non-null, an
          additional filter will be applied, using the interface on
          which packets are received.
        '';
      };

      v4 = mkOption {
        type = types.listOf pkgs.lib.types.ipv4CIDR;
        default = [];
        example = [ "10.0.0.0/24" ];
        description = ''
          A list of IPv4 addresses to be allowed access for the given
          protocol/port pair. Note that the addresses must be
          specified in CIDR notation, i.e., with a corresponding
          subnet prefix.
        '';
      };

      v6 = mkOption {
        type = types.listOf pkgs.lib.types.ipv6CIDR;
        default = [];
        example = [ "2001:db8::/64" ];
        description = ''
          A list of IPv6 addresses to be allowed access for the given
          protocol/port pair. Note that the addresses must be
          specified in CIDR notation, i.e., with a corresponding
          subnet prefix.
        '';
      };

    };
  });

}
