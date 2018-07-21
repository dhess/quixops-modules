## Punch holes in the firewall on a protocol/port/IP basis.

# TODO
# - Merge allowedIPs based on a protocol+port key.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.firewall;
  enable = cfg.allowedIPs != [] && cfg.enable;

  ipt = cmd: port: proto: ips:
    concatMapStrings (ip:
      ''
        ${cmd} -A nixos-fw -p ${proto} -s ${ip} --dport ${toString port} -j nixos-fw-accept
      ''
    ) ips;

  iptables = port: proto: v4: v6:
    ''
      ${ipt "iptables" port proto v4}
      ${ipt "ip6tables" port proto v6}
    '';
  
  extraCommands =
    concatMapStrings (desc:
      ''
        ${iptables desc.port desc.protocol desc.v4 desc.v6}
      ''
      ) cfg.allowedIPs;

in

{

  options.networking.firewall.allowedIPs = mkOption {
   type = pkgs.lib.types.allowedIPs;
   default = [];
   example = {
     protocol = tcp;
     port = 22;
     v4 = [ "10.0.0.0/24" ];
     v6 = [ "2001:db8::3:0/64" ];
   };
   description = ''
     A list of specific protocol+port+IP addresses on which incoming
     connections are accepted.

     This option provides finer-grained control than the
     <option>networking.firewall.allowedTCPPorts</option> etc. options
     provide.
   '';
  };

  config = mkIf enable {
    networking.firewall = { inherit extraCommands; };
  };

}
