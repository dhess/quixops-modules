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


  ## Anycast IP address "descriptors."

  anycastV4 = types.submodule {
    options = {

      ifnum = mkOption {
        type = types.unsigned;
        default = 0;
        description = ''
          All anycast addresses are assigned to a Linux
          <literal>dummy</literal> virtual interface. By default,
          this is <literal>dummy0</literal>, but you can specify a
          different index by setting it here.
        '';
      };

      addrOpts = mkOption {
        type = pkgs.lib.types.addrOptsV4;
        example = { address = "10.0.0.1"; prefixLength = 32; };
        description = ''
          The IPv4 anycast address (no CIDR suffix) and prefix.
        '';
      };

    };
  };

  anycastV6 = types.submodule {
    options = {

      ifnum = mkOption {
        type = types.unsigned;
        default = 0;
        description = ''
          All anycast addresses are assigned to a Linux
          <literal>dummy</literal> virtual interface. By default,
          this is <literal>dummy0</literal>, but you can specify a
          different index by setting it here.
        '';
      };

      addrOpts = mkOption {
        type = pkgs.lib.types.addrOptsV6;
        example = { address = "2001:db8::1"; prefixLength = 128; };
        description = ''
          The IPv6 anycast address (no CIDR suffix) and prefix.
        '';
      };

    };
  };

  anycastAddrs = types.submodule {
    options = {

      v4 = mkOption {
        type = types.listOf anycastV4;
        default = [];
        example = [ { ifnum = 0; addrOpts = { address = "10.8.8.8"; prefixLength = 32; }; } ];
        description = ''
          A list of IPv4 anycast addresses.
        '';
      };

      v6 = mkOption {
        type = types.listOf anycastV6;
        default = [];
        example = [ { ifnum = 0; addrOpts = { address = "2001:db8::1"; prefixLength = 128; }; } ];
        description = ''
          A list of IPv6 anycast addresses.
        '';
      };

    };
  };

  allowedIPs = types.listOf (types.submodule {
    options = {

      protocol = mkOption {
        type = types.enum [ "udp" "tcp" ];
        example = "tcp";
        description = "The protocol namespace of <option>port</option>.";
      };

      port = mkOption {
        type = pkgs.lib.types.port;
        example = 22;
        description = "The port number.";
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
