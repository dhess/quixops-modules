## Additional useful types, mostly for NixOS modules.

# The key type defined here is based on keyOptionType in NixOps. As it
# is a derivative work of NixOps, it is covered by the GNU LGPL; see
# the LICENSE file included with this source distribution.

{ lib
, pkgs
, ...
}:

with lib;

{
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
      default = null;
      type = types.nullOr types.str;
      description = ''
        When non-null, this designates the text that the key should contain. So if
        the key name is <replaceable>password</replaceable> and
        <literal>foobar</literal> is set here, the contents of the file
        <filename><replaceable>destDir</replaceable>/<replaceable>password</replaceable></filename>
        will be <literal>foobar</literal>.

        NOTE: Either <literal>text</literal> or <literal>keyFile</literal> have
        to be set.
      '';
    };

    options.keyFile = mkOption {
      default = null;
      type = types.nullOr pkgs.lib.types.nonStorePath;
      description = ''
        When non-null, contents of the specified file will be deployed to the
        specified key on the target machine.  If the key name is
        <replaceable>password</replaceable> and <literal>/foo/bar</literal> is set
        here, the contents of the file
        <filename><replaceable>destDir</replaceable>/<replaceable>password</replaceable></filename>
        deployed will be the same as local file <literal>/foo/bar</literal>.

        Since no serialization/deserialization of key contents is involved, there
        are no limits on that content: null bytes, invalid Unicode,
        <literal>/dev/random</literal> output -- anything goes.

        NOTE: Either <literal>text</literal> or <literal>keyFile</literal> have
        to be set.
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
}
