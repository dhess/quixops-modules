# An opinionated unbound instance that uses blocklists and forwards
# requests to Google DNS.
#
# Note that this service assigns one or more virtual IPs to a dummy
# network interface. You must ensure that those IPs are routed to the
# host on which the service runs.
#
# Other notes:
#
# - `allowedAccess` from the Nixpkgs unbound module is broken up into
#   separate IPv4 and IPv6 lists so that the addresses can easily be
#   added to firewall rules.
#
# TODO:
#
# - IPv6 service address.
#
# - Reload the block list when it is updated. Note -- this will
#   require unbound-control functionality, which is not currently
#   supported in Nixpkgs.

{ config, pkgs, lib, ... }:

with lib;

let

  seedBlockList = ./blocklist-someonewhocares.conf;

  cfg = config.services.unbound-adblock;

  # Note -- must match the definition in Nixpkgs unbound.nix!
  unboundStateDir = "/var/lib/unbound";

  blockListDir = "${unboundStateDir}/blocklists";
  blockListName = "blocklist-someonewhocares.conf";
  blockListFile = "${blockListDir}/${blockListName}";

  ipt4tcp = concatMapStringsSep "\n" (x: "iptables -A nixos-fw -p tcp -s ${x} --dport 53 -j nixos-fw-accept") cfg.allowedAccessIpv4;
  ipt4udp = concatMapStringsSep "\n" (x: "iptables -A nixos-fw -p udp -s ${x} --dport 53 -j nixos-fw-accept") cfg.allowedAccessIpv4;
  ipt6tcp = concatMapStringsSep "\n" (x: "ip6tables -A nixos-fw -p tcp -s ${x} --dport 53 -j nixos-fw-accept") cfg.allowedAccessIpv6;
  ipt6udp = concatMapStringsSep "\n" (x: "ip6tables -A nixos-fw -p udp -s ${x} --dport 53 -j nixos-fw-accept") cfg.allowedAccessIpv6;

in {

  options.services.unbound-adblock = {

    enable = mkEnableOption "An ad-blocking Unbound service";

    allowedAccessIpv4 = mkOption {
      default = [ "127.0.0.0/8" ];
      example = [ "192.168.1.0/24" ];
      type = types.listOf pkgs.lib.types.ipv4CIDR;
      description = ''
        A list of IPv4 networks that can use the server as a resolver,
        in CIDR notation.

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
        A list of IPv6 networks that can use the server as a resolver,
        in CIDR notation.

        Note that, in addition to specifying them in the Unbound
        service configuration, these addresses will also be added to
        the <literal>nixos-fw-accept</literal> firewall whitelist for
        port 53 (UDP and TCP).
      '';
    };

    virtualServiceIpv4s = mkOption {
      default = [ "10.8.8.8" ];
      example = [ "10.0.1.1" "10.1.1.1" ];
      type = types.listOf pkgs.lib.types.ipv4NoCIDR;
      description = ''
        A list of virtual IPv4 addresses on which the service will
        listen for requests. These addresses are assigned to the
        <literal>dummy0</literal> network device. Note that they are
        each configured as a <literal>/32</literal> address
        (single-host network).

        Use one of these addresses as your resolver address for
        clients, and make sure these addresses are routed to the host
        where the Unbound ad-block service is running.

        These addresses should not be used elsewhere in your network,
        except perhaps for other Unbound instances on other hosts,
        where you are using some sort of failover/load-balancing
        routing of virtual service IPs.

        Note: either this list or the
        <literal>virtualServiceIpv6s</literal> list can be the empty
        list (<literal>[]</literal>), but not both.
      '';
    };

    virtualServiceIpv6s = mkOption {
      default = [];
      example = [ "2001:db8::1" "2001:db8:3::1" ];
      type = types.listOf pkgs.lib.types.ipv6NoCIDR;
      description = ''
        A list of virtual IPv6 addresses on which the service will
        listen for requests. These addresses are assigned to the
        <literal>dummy0</literal> network device. Note that they are
        each configured as a <literal>/128</literal> address
        (single-host network).

        Use one of these addresses as your resolver address for
        clients, and make sure these addresses are routed to the host
        where the Unbound ad-block service is running.

        These addresses should not be used elsewhere in your network,
        except perhaps for other Unbound instances on other hosts,
        where you are using some sort of failover/load-balancing
        routing of virtual service IPs.

        Note: either this list or the
        <literal>virtualServiceIpv4s</literal> list can be the empty
        list (<literal>[]</literal>), but not both.
      '';
    };

    forwardAddresses = mkOption {
      default = [ "8.8.8.8" "8.8.4.4" "2001:4860:4860::8888" "2001:4860:4860::8844" ];
      example = [ "8.8.8.8" "2001:4860:4860::8888" ];
      type = types.nonEmptyListOf (types.either pkgs.lib.types.ipv4NoCIDR pkgs.lib.types.ipv6NoCIDR);
      description = ''
        The address(es) of forwarding servers for this Unbound
        service. Both IPv4 and IPv6 addresses are supported.
      '';
    };

    updateFrequency = mkOption {
      default = "daily";
      example = "hourly";
      type = pkgs.lib.types.nonEmptyStr;
      description = ''
        How often to update the block list. This value should be
        specified as a valid <literal>systemd.timers</literal>
        <literal>OnCalendar</literal> value.
      '';
    };
  };

  config = mkIf cfg.enable {

    assertions = [
      { assertion = (cfg.virtualServiceIpv4s == [] -> cfg.virtualServieIpv6s != []) &&
                    (cfg.virtualServiceIpv6s == [] -> cfg.virtualServiceIpv4s != []);
        message = "Both virtualServiceIpv4s and virtualServiceIpv6s cannot be the empty list";
      }
    ];

    quixops.assertions.moduleHashes."services/networking/unbound.nix" =
      "3147dfa48cc93e48d6b28a1106f793f7fb5d9fdbb8ce13f080d009796fa12659";

    # Note: I would prefer to assign an alias to lo, but, although
    # doing so does work, it causes network service timeouts during
    # deployments.

    boot.kernelModules = [ "dummy" ];
    networking.interfaces.dummy0.ipv4.addresses =
      map (ip: { address = ip; prefixLength = 32; }) cfg.virtualServiceIpv4s;
    networking.interfaces.dummy0.ipv6.addresses =
      map (ip: { address = ip; prefixLength = 128; }) cfg.virtualServiceIpv6s;

    services.unbound = {
      enable = true;
      allowedAccess = cfg.allowedAccessIpv4 ++ cfg.allowedAccessIpv6;
      interfaces = cfg.virtualServiceIpv4s ++ cfg.virtualServiceIpv6s;
      forwardAddresses = cfg.forwardAddresses;

      # Don't want DNSSEC, have had issues with it in the past where
      # failed DNSSEC causes very odd and hard-to-debug issues.
      enableRootTrustAnchor = false;

      extraConfig = ''
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

        include: "${blockListFile}"
      '';
    };

    systemd.services.pre-seed-unbound-adblock = {
      description = "Pre-seed Unbound's block list";
      before = [ "unbound.service" ];
      requiredBy = [ "unbound.service" ];
      script = ''
        mkdir -p -m 0755 ${blockListDir} > /dev/null 2>&1 || true
        if ! [ -e ${blockListFile} ] ; then
          echo "Pre-seeding unbound-adblock block list"
          cp ${seedBlockList} ${blockListFile}
        else
          echo "An unbound-adblock block lists already exists; skipping"
        fi
        chown -R unbound:nogroup ${blockListDir}
        find ${blockListDir} -type f -exec chmod 0644 {} \;
      '';
      restartIfChanged = true;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.services.update-unbound-block-hosts = {
      description = "Update Unbound's block list";
      after = [ "unbound.service" ];
      wantedBy = [ "unbound.service" ];
      script = ''
        until ${pkgs.unbound-block-hosts}/bin/unbound-block-hosts \
          --file ${blockListFile}.latest
        do
          sleep 10
        done

        [ -e ${blockListFile} ] && \
          cp ${blockListFile} ${blockListFile}.last

        cp ${blockListFile}.latest ${blockListFile}

        # Not yet working, need to run unbound-control-setup.
        # ${pkgs.unbound}/bin/unbound-control -c ${unboundStateDir}/unbound.conf reload
      '';
      restartIfChanged = true;

      serviceConfig = {
        PermissionsStartOnly = true;
        User = "unbound";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    systemd.timers.update-unbound-block-hosts = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.updateFrequency;
        Persistent = "yes";
      };
    };

    networking.firewall.extraCommands = ''
      ${ipt4tcp}
      ${ipt4udp}
      ${ipt6tcp}
      ${ipt6udp}
    '';

    meta = {
      maintainers = [ "Drew Hess <src@drewhess.com>" ];
    };
  };
}
