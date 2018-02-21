## Dummy (and insecure!) secret deployments for our tests.
##
## Do not use this in production -- it will put secrets into the Nix
## store.
##

# This code is derived from the key deployment code in NixOps. As a
# derivative work, it is covered by the LGPL. See the LICENSE file
# included with this source distribution.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.quixops.keychain;

  deployKeys =
    (concatStrings (mapAttrsToList
      (name: value: let
                      keyFile = pkgs.writeText name
                                (if !isNull value.keyFile
                                 then builtins.readFile value.keyFile
                                 else value.text);
                      destDir = toString value.destDir;
                    in
                    ''
                         if test ! -d ${destDir}
                         then
                             mkdir -p ${destDir} -m 0750
                             chown ${value.user}:${value.group} ${destDir}
                         fi
                         install -m ${value.permissions} -o ${value.user} -g ${value.group} ${keyFile} ${destDir}/${name}
                    '')
     cfg.keys));

in
{
  config = {

    # Emulate NixOps.
    system.activationScripts.nixops-keys = stringAfter [ "users" "groups" ]
      ''
        mkdir -p /run/keys -m 0750
        chown root:keys /run/keys
        ${deployKeys}
        touch /run/keys/done
      '';
  };
}
