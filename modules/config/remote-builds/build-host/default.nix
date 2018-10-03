{ config, lib, pkgs, ... }:

let

  cfg = config.quixops.build-host;
  enabled = cfg.enable;

  sshKeyName = host: user: "${user}_at_${host}";

  buildMachines = lib.mapAttrsToList (host: descriptor: with descriptor;
    {
      inherit hostName systems maxJobs speedFactor mandatoryFeatures supportedFeatures;
      sshUser = "ssh://${sshUserName}";
      sshKey =
      let
        keyname = sshKeyName host sshUserName;
      in
        config.quixops.keychain.keys.${keyname}.path;
    }
  ) cfg.buildMachines;

  knownHosts = lib.mapAttrsToList (host: descriptor:
    {
      hostNames = lib.singleton descriptor.hostName ++ descriptor.alternateHostNames;
      publicKey = descriptor.hostPublicKeyLiteral;
    }
  ) cfg.buildMachines;

  keys = lib.mapAttrs' (host: descriptor:
  let
    keyName = sshKeyName host descriptor.sshUserName;
  in
    lib.nameValuePair keyName {
      destDir = cfg.sshKeyDir;
      text = descriptor.sshKeyLiteral;
      user = cfg.sshKeyFileOwner;
      group = "root";
      permissions = "0400";
  }) cfg.buildMachines;

in
{

  options.quixops.build-host = {
    enable = lib.mkEnableOption ''
      This host is a build host, i.e., a machine from which Nixpkgs
      builds can be performed using remote builders.

      This module will configure this host to use the given remote
      build hosts as remote builders. This includes setting the
      <option>nix.buildMachines</option>, as well as all of the user
      and host keys needed by SSH to log into those remote builders
      without needing any manual set-up. (For example, most Nix guides
      to remote builds tell you to manually SSH to the remote build
      host once before enabling remote builds, in order to get SSH to
      accept the remote build host's host key; but if you configure
      this module properly, that will not be necessary.)
    '';

    sshKeyDir = lib.mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      default = "/etc/nix";
      example = "/var/lib/remote-build-keys";
      description = ''
        A directory where the SSH private keys for the remote build
        host users are stored.

        These keys will be deployed securely to this directory on the
        build host; i.e., they will not be copied to the Nix store.
      '';
    };

    sshKeyFileOwner = lib.mkOption {
      type = pkgs.lib.types.nonEmptyStr;
      default = "root";
      example = "hydra-queue-runner";
      description = ''
        The name of the user who will own the SSH private keys for
        remote build host users, giving that user read-only access to
        the key. No other user or group will be able to read the keys,
        and no user or group will be permitted to write them.

        If you are running a Hydra server on this build host, and you
        plan to use the same set of build hosts and SSH keys for the
        Hydra server as the ones you are defining in this module, then
        you'll want to set this option to
        <literal>hydra-queue-runner</literal>; otherwise, the default
        value (<literal>root</literal>) is usually the one you want.
      '';
    };

    buildMachines = lib.mkOption {
      default = {};
      description = "An attrset containing remote build host descriptors.";
      type = lib.types.attrsOf pkgs.lib.types.remoteBuildHost;
    };
  };

  config = lib.mkIf enabled {

    assertions = [
      {  assertion = cfg.buildMachines != {};
         message = "`quixops.build-host` is enabled, but `quixops.build-host.buildMachines` is empty";
      }
    ];

    nix.distributedBuilds = true;
    nix.buildMachines = buildMachines;

    programs.ssh.knownHosts = knownHosts;

    quixops.keychain.keys = keys;

  };

}
