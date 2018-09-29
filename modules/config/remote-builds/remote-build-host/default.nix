{ config, lib, pkgs, ... }:

let

  cfg = config.quixops.remote-build-host;
  enabled = cfg.enable;

in
{

  options.quixops.remote-build-host = {
    enable = lib.mkEnableOption ''
      This host is a remote builder, i.e., a machine that performs
      Nix builds for other hosts.

      Enabling this option will create a user dedicated to remote
      builds. This user will be added to
      <literal>nix.trustedUsers</literal>.
    '';

    user = {
      name = lib.mkOption {
        type = pkgs.lib.types.nonEmptyStr;
        default = "remote-builder";
        readOnly = true;
        description = ''
          The name of the user that's created by this module to run
          remote builds.

          This is a read-only attribute and is provided so that other
          modules can refer to it.
        '';
      };

      sshKeyFiles = lib.mkOption {
        type = lib.types.nonEmptyListOf lib.types.path;
        example = lib.literalExample [ ./remote-builder.pub ];
        description = ''
          The public SSH keys used to identify the remote builder
          user. The corresponding private keys should be installed on
          the build host that is using this remote builder.
        '';
      };
    };

  };

  config = lib.mkIf enabled {

    quixops.defaults.ssh.enable = true;

    nix.trustedUsers = [ cfg.user.name ];

    users.users."${cfg.user.name}" = {
      useDefaultShell = true;
      description = "Nix remote builder";
      openssh.authorizedKeys.keyFiles = cfg.user.sshKeyFiles;
    };

    # Useful utilities.
    environment.systemPackages = with pkgs; [
      htop
      pythonPackages.glances
    ];
  };

}
