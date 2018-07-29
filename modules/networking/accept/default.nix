## Punch holes in the firewall on a protocol/port/IP basis.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.firewall;
  enable = cfg.accept != [] && cfg.enable;

  ipt = cmd: port: proto: sourcePort: ifname: ips:
  let
    sourcePortFilter = optionalString (sourcePort != null) "--sport ${toString sourcePort}";
    ifFilter = optionalString (ifname != null) "-i ${ifname}";
  in
    if (ips == []) then ''
      ${cmd} -A nixos-fw -p ${proto} ${ifFilter} ${sourcePortFilter} --dport ${toString port} -j nixos-fw-accept
    ''
    else
      concatMapStrings (ip:
        ''
          ${cmd} -A nixos-fw -p ${proto} -s ${ip} ${ifFilter} ${sourcePortFilter} --dport ${toString port} -j nixos-fw-accept
        ''
      ) ips;

  iptables = port: proto: sourcePort: ifname: v4: v6:
    ''
      ${ipt "iptables" port proto sourcePort ifname v4}
      ${ipt "ip6tables" port proto sourcePort ifname v6}
    '';
  
  extraCommands =
    concatMapStrings (desc:
      ''
        ${iptables desc.port desc.protocol desc.sourcePort desc.interface desc.v4 desc.v6}
      ''
      ) cfg.accept;

in

{

  options.networking.firewall.accept = mkOption {
   type = pkgs.lib.types.fwRule;
   default = [];
   example = [ {
     protocol = "tcp";
     port = 22;
     v4 = [ "10.0.0.0/24" ];
     v6 = [ "2001:db8::3:0/64" ];
   } ];
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
