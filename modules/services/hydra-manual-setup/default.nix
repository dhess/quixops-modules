{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.hydra-manual-setup;

  publicKeyFile = pkgs.writeText "public" (builtins.readFile cfg.binaryCache.publicKey);

  defaultPasswordHashKeyName = "hydra-admin-pw-sha1";

  defaultBinaryCacheKeyName = "hydra-binary-cache";

in
{
  options = {

    services.hydra-manual-setup = {

      description = ''
        This service, when enabled along with the
        <literal>hydra</literal> service, will do all of the initial
        Hydra setup that normally needs to be done manually.
        Specifically, it will create the admin user and set the admin
        user's initial password in a relatively secure manner; see
        <option>adminUser.initialPasswordHash</option> for details.

        The service will also copy the server's binary cache
        public/private keypair to a specified location on the Hydra
        server's filesystem.

        This service will only run once (successfully) and will
        effectively be a no-op from that point on.
      '';

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          To use the <literal>hydra-manual-setup</literal> service,
          set this option to <literal>true</literal>. Note that the
          service will only actually run if both this option and
          <literal>services.hydra</literal> are
          <literal>true</literal>.
        '';
      };

      adminUser = {

        fullName = mkOption {
          type = types.str;
          example = "Hydra Admin";
          description = ''
            The full name of the Hydra admin user.
          '';
        };

        userName = mkOption {
          type = types.str;
          example = "admin";
          description = ''
            The username of the Hydra admin user in the Hydra web
            interface.
          '';
        };

        email = mkOption {
          type = types.str;
          example = "hydra@example.com";
          description = ''
            The email address of the Hydra admin user.
          '';
        };

        initialPasswordHash = mkOption {
          type = types.path;
          default = "/run/keys/${defaultPasswordHashKeyName}";
          description = ''
            The SHA1 hash of the Hydra admin user's initial password.
            Note that this file will not copied to the Nix store; the
            service will expect the file to be at the given path when
            the service starts, so it must be deployed to the Hydra
            server out-of-band.

            The default value specifies a NixOps
            <option>deployment.keys</option> path. If you use NixOps
            and you deploy the key to this path, the
            <literal>hydra-manual-setup</literal> service will
            automatically wait for that key to be present before it
            runs.

            You can generate the SHA1 hash of the password via the command:

            <command>echo myP4ssw0rd | openssl dgst -sha1</command>
            
            The <command>hydra-create-user</command> command used to
            create this user only takes password hashes as strings on
            the command line, so there is a small chance that an
            attacker who is on the Hydra master system could see the
            <command>hydra-create-user</command> command as it runs
            using a process tool such as <command>ps</command>, and
            therefore also see the initial admin user password hash
            command-line argument.

            To be fair, the exact same scenario applies if you run the
            <command>hydra-create-user</command> command by hand, so
            this risk is not unique to this service and is inherent to
            <command>hydra-create-user</command>. In any case, to be
            truly safe, you should change this initial password by
            logging into the Hydra web console and changing it there.
          ''; };

      };

      binaryCacheKey = {

        public = mkOption {
          type = types.path;
          example = ./hydra-bc.public;
          description = ''
            The Hydra server's binary cache public key.

            You can create the public/private keypair with the command:

            <command>nix-store --generate-binary-cache-key hydra.example.com-1 hydra-example.com-1/secret hydra-example.com-1/public</command>

            Because it is public, this key will automatically be
            copied to the Hydra server via the Nix store. You do not
            need to arrange for it to be copied out-of-band.

            The service will copy the key to the file
            <literal>${binaryCacheDir}/public</literal>.
          '';
        };

        private = mkOption {
          type = types.path;
          default = "/run/keys/${defaultBinaryCacheKeyName}";
          description = ''
            The Hydra server's binary cache private key. Note that
            this file will not be copied to the Nix store; the service
            will expect the file to be at the given path when the
            service starts, so it must be deployed to the Hydra server
            out-of-band.

            The default value specifies a NixOps
            <option>deployment.keys</option> path. If you use NixOps
            and you deploy the key to this default path, the
            <literal>hydra-manual-setup</literal> service will
            automatically wait for that key to be present before it
            runs.

            The service will copy the key to the file
            <literal>${binaryCacheDir}/secret</literal>.
          '';
        };

        directory = mkOption {
          type = types.path;
          example = "/etc/nix/hydra-bc";
          description = ''
            The public and private key files will be installed in this
            directory as <literal>directory/public</literal> and
            <literal>directory/secret</literal>, respectively.
          '';
        };

      };

    };

  };

  config = mkIf (cfg.enable && config.services.hydra.enable) {

    systemd.services.hydra-manual-setup = rec {

      description = "Automate Hydra's initial manual setup";
      wantedBy = [ "multi-user.target" ];
      wants = [
        "${defaultPasswordHashKeyName}-key.service"
        "${defaultBinaryCacheKeyName}-key.service"
      ];
      requires = [ "hydra-init.service" ];
      after = [ "hydra-init.service" ] ++ wants;

      environment = config.systemd.services.hydra-init.environment;
      script =
      let bcKeyDir = cfg.binaryCacheKey.directory;
      in ''
        if [ ! -e ~hydra/.manual-setup-is-complete-v1 ]; then
          HYDRA_PW_HASH=$(cat "${toString cfg.adminUser.initialPasswordHash}")
          "${pkgs.hydra}"/bin/hydra-create-user ${cfg.adminUser.userName} --full-name "${cfg.adminUser.fullName}" --email-address ${cfg.adminUser.email} --role admin --password-hash $HYDRA_PW_HASH

          install -d -m 551 "${bcKeyDir}"
          cp "${toString cfg.binaryCacheKey.private}" "${bcKeyDir}/secret"
          chmod 0440 "${bcKeyDir}/secret"
          cp "${cfg.binaryCacheKey.public}" "${bcKeyDir}/public"
          chmod 0444 "${bcKeyDir}/public"
          chown -R hydra:hydra "${bcKeyDir}"

          touch ~hydra/.manual-setup-is-complete-v1
        fi
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

    };

  };

}
