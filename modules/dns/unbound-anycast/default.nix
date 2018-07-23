# An opinionated anycast unbound instance.
#
# Other notes:
#
# - `allowedAccess` from the Nixpkgs unbound module is broken up into
#   separate IPv4 and IPv6 lists so that the addresses can easily be
#   added to firewall rules.

{ config, pkgs, lib, ... }:

with lib;

let

  globalCfg = config.services.unbound-anycast;

  stateDir = "/var/lib/unbound-anycast";
  blockList = ./blocklist-someonewhocares.conf;

  mkServiceName = name: "unbound-anycast-${name}";

  mkUnboundService = name: cfg:
  let
    isLocalAddress = x: substring 0 3 x == "::1" || substring 0 9 x == "127.0.0.1";
    rootTrustAnchorFile = "${stateDir}/root.key";
    confFile = pkgs.writeText "unbound-anycast-${name}.conf" ''
      server:
        directory: "${stateDir}"
        username: unbound
        chroot: "${stateDir}"
        pidfile: ""
        ${concatMapStringsSep "\n  " (x: "interface: ${x.addrOpts.address}") cfg.anycastAddrs.v4}
        ${concatMapStringsSep "\n  " (x: "interface: ${x.addrOpts.address}") cfg.anycastAddrs.v6}
        ${concatMapStringsSep "\n  " (x: "access-control: ${x} allow") cfg.allowedAccessIpv4}
        ${concatMapStringsSep "\n  " (x: "access-control: ${x} allow") cfg.allowedAccessIpv6}
        ${optionalString cfg.enableRootTrustAnchor "auto-trust-anchor-file: ${rootTrustAnchorFile}"}

      unwanted-reply-threshold: 10000000

      verbosity: 3
      prefetch: yes
      prefetch-key: yes

      hide-version: yes
      hide-identity: yes

      private-address: 10.0.0.0/8
      private-address: 172.16.0.0/12
      private-address: 192.168.0.0/16
      private-address: 169.254.0.0/16
      private-address: fd00::/8
      private-address: fe80::/10

      ${optionalString cfg.blockList.enable "include: ${blockList}"}
      ${cfg.extraConfig}
      ${optionalString (any isLocalAddress cfg.forwardAddresses) ''
          do-not-query-localhost: no
        '' +
        optionalString (cfg.forwardAddresses != []) ''
          forward-zone:
            name: .
        '' +
        concatMapStringsSep "\n" (x: "    forward-addr: ${x}") cfg.forwardAddresses}
    '';
  in nameValuePair (mkServiceName name)
  {
    description = "Unbound recursive name server (anycast)";
    after = [ "network.target" ];
    before = [ "nss-lookup.target" ];
    wants = [ "nss-lookup.target" ];
    wantedBy = [ "multi-user.target" ];

    preStart = ''
      mkdir -m 0755 -p ${stateDir}/dev/
      ${optionalString cfg.enableRootTrustAnchor ''
        ${pkgs.unbound}/bin/unbound-anchor -a ${rootTrustAnchorFile} || echo "Root anchor updated!"
        chown unbound ${stateDir} ${rootTrustAnchorFile}
      ''}
      touch ${stateDir}/dev/random
      ${pkgs.utillinux}/bin/mount --bind -n /dev/urandom ${stateDir}/dev/random
    '';

    serviceConfig = {
      ExecStart = "${pkgs.unbound}/bin/unbound -d -c ${confFile}";
      ExecStopPost="${pkgs.utillinux}/bin/umount ${stateDir}/dev/random";

      ProtectSystem = true;
      ProtectHome = true;
      PrivateDevices = true;
      Restart = "always";
      RestartSec = "5s";
    };
  };

in {

  options.services.unbound-anycast = {

    instances = mkOption {
      description = ''
        Unbound anycast service instances.
      '';
      default = {};
      example = {
        adblock = {
          blockList.enable = true;
          allowedAccessIpv4 = [ "10.0.0.0/8" ];
          anycastAddrs.v4 = [
            { ifnum = 0; addrOpts = { address = "10.8.8.8"; prefixLength = 32; }; }
          ];
        };
      };
      type = types.attrsOf (types.submodule {
        options = {

          blockList = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = ''
                If true, this Unbound instance will use a blocklist to block
                unwanted domains; these domains will return an address of
                <literal>127.0.0.1</literal> or <literal>::1</literal>.
              '';
            };
          };

          allowedAccessIpv4 = mkOption {
            default = [ "127.0.0.0/8" ];
            example = [ "192.168.1.0/24" ];
            type = types.listOf pkgs.lib.types.ipv4CIDR;
            description = ''
              A list of IPv4 networks that can use this instance as
              a resolver, in CIDR notation.

              Note that, in addition to specifying them in the Unbound
              service configuration, these addresses will also be added to
              the <literal>nixos-fw-accept</literal> firewall whitelist for
              port 53 (UDP and TCP).
            '';
          };

          allowedAccessIpv6 = mkOption {
            default = [ "::1/128" ];
            example = [ "2001:db8::/32" ];
            type = types.listOf pkgs.lib.types.ipv6CIDR;
            description = ''
              A list of IPv6 networks that can use this instance as
              a resolver, in CIDR notation.

              Note that, in addition to specifying them in the Unbound
              service configuration, these addresses will also be added to
              the <literal>nixos-fw-accept</literal> firewall whitelist for
              port 53 (UDP and TCP).
            '';
          };

          anycastAddrs = mkOption {
            type = pkgs.lib.types.anycastAddrs;
            default = { v4 = []; v6 = []; };
            example = {
              v4 = [ { ifnum = 0; addrOpts = { address = "10.8.8.8"; prefixLength = 32; }; } ];
              v6 = [ { ifnum = 0; addrOpts = { address = "2001:db8::1"; prefixLength = 128; }; } ];
            };
            description = ''
              A set of IPv4 and IPv6 anycast addresses on which this
              Unbound instance will listen.
            '';
          };

          forwardAddresses = mkOption {
            default = pkgs.lib.dns.googleDNS;
            example = [ "8.8.8.8" "2001:4860:4860::8888" ];
            type = types.nonEmptyListOf (types.either pkgs.lib.types.ipv4NoCIDR pkgs.lib.types.ipv6NoCIDR);
            description = ''
              The address(es) of forwarding servers for this Unbound
              instance. Both IPv4 and IPv6 addresses are supported.
            '';
          };

          enableRootTrustAnchor = mkOption {
            default = true;
            type = types.bool;
            description = "Use and update root trust anchor for DNSSEC validation on this Unbound instance.";
          };

          extraConfig = mkOption {
            default = "";
            type = types.lines;
            description = "Extra Unbound config for this instance.";
          };

        };
      });
    };

  };

  config = mkIf (globalCfg.instances != {}) {

    assertions =
    let
      mkAssertion = name: cfg:
        { assertion = (cfg.anycastAddrs.v4 == [] -> cfg.anycastAddrs.v6 != []) &&
                      (cfg.anycastAddrs.v6 == [] -> cfg.anycastAddrs.v4 != []);
          message = "At least one anycast address must be set in `services.unbound-anycast.${name}`";
        };
    in mapAttrsToList mkAssertion globalCfg.instances;

    # Track changes in upstream service, in case we need to reproduce
    # them here.

    quixops.assertions.moduleHashes."services/networking/unbound.nix" =
      "28324ab792c2eea96bce39599b49c3de29f678029342dc57ffcac186eee22f7b";

    networking.anycastAddrs.v4 =
      flatten (pkgs.lib.attrsets.mapValuesToList (cfg: cfg.anycastAddrs.v4) globalCfg.instances);
    networking.anycastAddrs.v6 =
      flatten (pkgs.lib.attrsets.mapValuesToList (cfg: cfg.anycastAddrs.v6) globalCfg.instances);

    environment.systemPackages = [ pkgs.unbound ];

    users.users.unbound = {
      description = "unbound daemon user";
      isSystemUser = true;
    };

    systemd.services =
      mapAttrs' mkUnboundService globalCfg.instances;

    networking.firewall.allowedIPs =
    let
      mkAllowedIPs = protocol: cfg:
        { inherit protocol; port = 53; v4 = cfg.allowedAccessIpv4; v6 = cfg.allowedAccessIpv6; };
    in    
      (pkgs.lib.attrsets.mapValuesToList (cfg: mkAllowedIPs "tcp" cfg) globalCfg.instances)
      ++ (pkgs.lib.attrsets.mapValuesToList (cfg: mkAllowedIPs "udp" cfg) globalCfg.instances);

  };

  meta.maintainers = lib.maintainers.dhess-qx;

}
