# A service for running a high-performance instance(s) of netsniff-ng.
#
# This service assumes you've set up some kind of SPAN port(s) on your
# switch, or added a TAP device(s), to mirror/capture packets and have
# them sent to the interface(s) on which netsniff-ng listens.
#
# Most of the dirty tricks employed by this service come from the
# following sources:
#
# http://blog.securityonion.net/2011/10/when-is-full-packet-capture-not-full.html
# http://mailman.icsi.berkeley.edu/pipermail/bro/2017-January/011280.html
# https://groups.google.com/forum/#!topic/security-onion/1nW4M4zD9D4
# https://github.com/pevma/SEPTun
# https://github.com/Security-Onion-Solutions/securityonion-nsmnow-admin-scripts/blob/21e36844409f8b863b4558912aefc085283fb408/usr/sbin/nsm_sensor_ps-start#L466

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.netsniff-ng;

  defaultUser = "netsniff-ng";
  defaultGroup = "netsniff-ng";


  outputDir = conf: "${toString conf.outputBaseDirectory}/${conf.name}";
  outputDirPerms = "u+rwx,g+rx,o-rwx";

  instancesList = mapAttrsToList (_: config: config) cfg.instances;

  perInstanceAssertions = c: [
    {
      assertion = c.inputInterface != "";
      message = "services.netsniff-ng.instances.${c.name}.inputInterface cannot be the empty string.";
    }
    {
      assertion = c.outputBaseDirectory != "";
      message = "services.netsniff-ng.instances.${c.name}.outputBaseDirectory cannot be the empty string.";
    }
  ];

  preCmd = conf:
  let
    dir = outputDir conf;
  in ''
    if [[ ! -d "${dir}" ]]; then
      mkdir -p "${dir}"
    fi
    chown ${cfg.user}:${cfg.group} "${dir}"
    chmod ${outputDirPerms} "${dir}"
  '';

  netsniffNgCmd = conf:
  let
    dir = outputDir conf;
  in ''
    USERID=`id -u ${cfg.user}`
    GROUPID=`id -g ${cfg.group}`
    ${pkgs.netsniff-ng}/bin/netsniff-ng --in ${conf.inputInterface} --out "${dir}"       \
      ${optionalString (conf.bindToCPU != null) "--bind-cpu ${toString conf.bindToCPU}"} \
      ${optionalString (conf.interval != "") "--interval ${conf.interval}"}              \
      ${optionalString (conf.packetType != null) "--type ${conf.packetType}"}            \
      ${optionalString (conf.pcapMagic != "") "--magic ${conf.pcapMagic}"}               \
      ${optionalString (conf.pcapPrefix != "") "--prefix ${conf.pcapPrefix}"}            \
      ${optionalString (conf.ringSize != "") "--ring-size ${conf.ringSize}"}             \
      --user $USERID --group $GROUPID                                                    \
      --silent --verbose ${conf.extraOptions}
  '';

in
{
  options = {
    services.netsniff-ng = {

      user = mkOption {
        type = types.string;
        default = defaultUser;
        description = ''
          All <literal>netsniff-ng</literal> services will run as this
          user after the initial setup.

          If you do not override the default value, an unprivileged
          user will be created for this purpose.
        '';
      };

      group = mkOption {
        type = types.string;
        default = defaultGroup;
        description = ''
          All <literal>netsniff-ng</literal> services will run as this
          group after the initial setup.

          If you do not override the default value, an unprivileged
          group will be created for this purpose.
        '';
      };

      instances = mkOption {
        type = types.attrsOf (types.submodule ({ name, ... }: (import ./netsniff-ng-options.nix {
          inherit name config lib outputDirPerms;
        })));
        default = {};
        example = literalExample ''
          full-cap = {
            inputInterface = "eno1";
            interval = "1MiB";
            bindToCPU = 0;
          };
        '';
        description = ''
          Zero or more netsniff-ng instances for packet capture,
          analysis, or redirection.

          Note that there are many fiddly <command>netsniff-ng</command>
          options, many of which have profound performance implications.
          Only some of the <command>netsniff-ng</command> options have
          corresponding configuration options, and those that do only
          provide a brief explanation of their significance. See
          <citerefentry><refentrytitle>netsniff-ng</refentrytitle><manvolnum>8</manvolnum></citerefentry>
          for the full documentation of these options and their
          performance implications. To get high performance with
          relative few dropped packets, you will likely need to do quite
          a bit of hardware-specific performance tuning.

          <command>netsniff-ng</command> options that do not have a
          corresponding configuration option can be passed as a raw
          string to the <literal>netsniff-ng</literal> service instance
          via the <option>extraOptions</option> option.
        '';
      };
    };

  };

  config = mkIf (cfg.instances != {}) {

    assertions =
      (flatten (map perInstanceAssertions instancesList)) ++
      [
        { assertion = cfg.group != "";
          message = "services.netsniff-ng.group cannot be the empty string."; }
        { assertion = cfg.user != "";
          message = "serivces.netsniff-ng.user cannot be the empty string."; }
      ];

    users.users = optional (cfg.user == defaultUser) {
      name = defaultUser;
      description = "Packet capture user";
      group = cfg.group;
    };

    users.groups = optional (cfg.group == defaultGroup) {
      name = defaultGroup;
    };

    # Configure each interface for packet capture.
    networking.interfaces = listToAttrs (filter (x: x.value != null) (
      (mapAttrsToList
        (_: conf: nameValuePair "${conf.inputInterface}" ({

          useDHCP = false;

        })) cfg.instances)
    ));

    systemd.services = listToAttrs (filter (x: x.value != null) (
      (mapAttrsToList
        (_: conf: nameValuePair "netsniff-ng@${conf.name}" ({

          description = "Packet capture (${conf.name})";
          wantedBy = [ "multi-user.target" ];
          after = [ "network.target" "local-fs.target" ] ++ conf.serviceRequires;
          requires = conf.serviceRequires;
          preStart = preCmd conf;
          script = netsniffNgCmd conf;

        })) cfg.instances)
    ));

    environment.systemPackages = [ pkgs.netsniff-ng ];

  };
}
