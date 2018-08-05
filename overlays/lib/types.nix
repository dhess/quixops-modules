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


  fwRule = types.listOf (types.submodule {
    options = {

      protocol = mkOption {
        type = pkgs.lib.types.nonEmptyStr;
        example = "tcp";
        description = ''
          The protocol of the rule or packet to check.
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

      src = {
        port = mkOption {
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

        ip = mkOption {
          type = types.nullOr pkgs.lib.types.ipv4CIDR;
          default = null;
          example = "10.0.0.0/24";
          description = ''
            An optional source IP address to filter on. Note that
            the address must be specified in CIDR notation, i.e., with a
            corresponding subnet prefix. Use "/32" for singleton IP
            addresses.
          '';
        };
      };

      dest = {
        port = mkOption {
          type = types.nullOr (types.either pkgs.lib.types.port (types.strMatching "[[:digit:]]+:[[:digit:]]+"));
          default = null;
          example = "8000:8007";
          description = ''
            An optional destination port number, or colon-delimited port number range.
          '';
        };

        ip = mkOption {
          type = types.nullOr pkgs.lib.types.ipv4CIDR;
          default = null;
          example = "10.0.0.0/24";
          description = ''
            An optional destination IP address to filter on. Note that
            the address must be specified in CIDR notation, i.e., with a
            corresponding subnet prefix. Use "/32" for singleton IP
            addresses.
          '';
        };
      };

    };
  });

  fwRule6 = types.listOf (types.submodule {
    options = {

      protocol = mkOption {
        type = pkgs.lib.types.nonEmptyStr;
        example = "tcp";
        description = ''
          The protocol of the rule or packet to check.
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

      src = {
        port = mkOption {
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

        ip = mkOption {
          type = types.nullOr pkgs.lib.types.ipv6CIDR;
          default = null;
          example = "2001:db8::3:0/64";
          description = ''
            An optional source IPv6 address to filter on. Note that
            the address must be specified in CIDR notation, i.e., with a
            corresponding network prefix. Use "/128" for singleton IPv6
            addresses.
          '';
        };
      };

      dest = {
        port = mkOption {
          type = types.nullOr (types.either pkgs.lib.types.port (types.strMatching "[[:digit:]]+:[[:digit:]]+"));
          default = null;
          example = "8000:8007";
          description = ''
            An optional destination port number, or colon-delimited port number range.
          '';
        };

        ip = mkOption {
          type = types.nullOr pkgs.lib.types.ipv6CIDR;
          default = null;
          example = "2001:db8::3:0/64";
          description = ''
            An optional destination IPv6 address to filter on. Note that
            the address must be specified in CIDR notation, i.e., with a
            corresponding network prefix. Use "/128" for singleton IPv6
            addresses.
          '';
        };
      };

    };
  });


  ## An IPv4 subnet description. This could be used for, e.g.,
  ## generating IPv4 subnet stanzas for dhcpd.

  ipv4Subnet = types.submodule {
    options = {

      description = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "The foo subnet";
        description = ''
          An optional one-line description of the subnet.
        '';
      };

      nocidr = {

        ip = mkOption {
          type = pkgs.lib.types.ipv4NoCIDR;
          example = "192.168.1.0";
          description = ''
            The IPv4 address of the subnet, with no CIDR prefix.
          '';
        };

        netmask = mkOption {
          type = pkgs.lib.types.ipv4NoCIDR;
          example = "255.255.255.0";
          description = ''
            The IPV4 subnet netmask (4 octets).
          '';
        };

      };

      router = mkOption {
        type = types.nullOr pkgs.lib.types.ipv4NoCIDR;
        example = "192.168.1.1";
        description = ''
          The subnet's default router, expressed as an IPv4 address.

          Technically this attribute is optional; it can be set to
          <literal>null</literal>. This is useful for things like
          point-to-point networks, or networks that should not be
          routed, like inter-router communication networks. However,
          there is no default value, to prevent you from forgetting to
          configure one.
        '';
      };

      dhcp.range = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            start = mkOption {
              type = pkgs.lib.types.ipv4NoCIDR;
            };
            end = mkOption {
              type = pkgs.lib.types.ipv4NoCIDR;
            };
          };
        });
        default = null;
        example = {
          start = "192.168.1.200";
          end = "192.168.1.220";
        };
        description = ''
          An optional range of dynamic addresses, for use with dhcpd.
        '';
      };

      dhcp.leaseTime = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            default = mkOption {
              type = types.ints.unsigned;
            };
            max = mkOption {
              type = types.ints.unsigned;
            };
          };
        });
        default = null;
        example = {
          default = 3600;
          max = 7200;
        };
        description = ''
          An optional default and maximum lease time for the subnet,
          which override the global defaults.
        '';
      };

      dhcp.nameservers = mkOption {
        type = types.listOf (types.either pkgs.lib.types.ipv4NoCIDR pkgs.lib.types.ipv6NoCIDR);
        default = [];
        example = [ "192.168.0.8" "2001:db8::8" ];
        description = ''
          An optional list of IPv4 and IPv6 addresses of nameservers
          for clients on this subnet, which overrides the global
          default.
        '';
      };

      dhcp.deny = mkOption {
        type = types.listOf pkgs.lib.types.nonEmptyStr;
        default = [];
        example = [ "unknown-clients" ];
        description = ''
          An optional list of <literal>dhcpd</literal>
          <literal>deny</literal> directives for this subnet.
        '';
      };

    };
  };

}
