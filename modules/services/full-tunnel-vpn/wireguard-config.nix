{ cfg, lib, pkgs, keys, ... }:

with lib;

let

  stateDir = "/var/lib/wireguard";
  privateKeyFile = "${stateDir}/key";

in
mkIf (cfg.peers != {}) {

  quixops.assertions.moduleHashes."services/networking/wireguard.nix" =
    "2cab968eeefd4010160235fc780add00cc98dda499aa1c156188e23baa11a89c";

  quixops.keychain.keys = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: peerCfg: nameValuePair "wireguard-${cfg.interface}-${peerCfg.name}-psk" ({
        text = peerCfg.presharedKeyLiteral;
      })) cfg.peers) ++
    (mapAttrsToList
      (_: _: nameValuePair "wireguard-${cfg.interface}-key" ({
        text = cfg.privateKeyLiteral;
      })) { dummy = "foo"; })
  ));

  networking.wireguard.interfaces.${cfg.interface} = {
    ips = [ cfg.ipv4ClientCidr cfg.ipv6ClientPrefix ];
    inherit privateKeyFile;
    listenPort = cfg.listenPort;
    peers =
      (mapAttrsToList
        (_: peerCfg: (
          {
            publicKey = pkgs.lib.fileContents peerCfg.publicKeyFile;
            allowedIPs = peerCfg.allowedIPs;
            presharedKeyFile = "${stateDir}/${peerCfg.name}/psk";
            persistentKeepalive = 30;
          }
        )) cfg.peers);
  };

  networking.firewall.allowedUDPPorts = [ cfg.listenPort ];

  networking.nat.internalIPs = lib.flatten
    (mapAttrsToList
      (_: peerCfg: (
        peerCfg.natInternalIPs
      )) cfg.peers);

  systemd.services = listToAttrs (filter (x: x.value != null) (
    (mapAttrsToList
      (_: peerCfg: nameValuePair "wireguard-${cfg.interface}-${peerCfg.name}-setup" ({
          description = "wireguard-${cfg.interface} setup script for peer ${peerCfg.name}";
          wantedBy = [ "multi-user.target" ];
          wants = [ "keys.target" ];
          after = [ "keys.target" ];
          requiredBy = [ "wireguard-${cfg.interface}.service" ];
          before = [ "wireguard-${cfg.interface}.service" ];
          script =
          let
            dir = "${stateDir}/${peerCfg.name}";
            deployedPSK = keys."wireguard-${cfg.interface}-${peerCfg.name}-psk".path;
          in
          ''
            install -m 0700 -o root -g root -d ${dir} > /dev/null 2>&1 || true
            install -m 0400 -o root -g root ${deployedPSK} ${dir}/psk
          '';
        })) cfg.peers) ++
    (mapAttrsToList
      (_: _: nameValuePair "wireguard-${cfg.interface}-setup" ({
          description = "wireguard-${cfg.interface} setup script";
          wantedBy = [ "multi-user.target" ];
          wants = [ "keys.target" ];
          after = [ "keys.target" ];
          requiredBy = [ "wireguard-${cfg.interface}.service" ];
          before = [ "wireguard-${cfg.interface}.service" ];
          script =
          let
            deployedKey = keys."wireguard-${cfg.interface}-key".path;
          in
          ''
            install -m 0700 -o root -g root -d ${stateDir} > /dev/null 2>&1 || true
            install -m 0400 -o root -g root ${deployedKey} ${privateKeyFile}
          '';
      })) { dummy = "foo"; })
  ));

}
