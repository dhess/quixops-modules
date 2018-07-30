## Punch holes in the firewall on a protocol/port/IP basis.

{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking.firewall;
  enable = cfg.accept != [] && cfg.enable;

  ipt = cmd: desc:
  let
    sourcePortFilter = optionalString (desc.sourcePort != null) "--sport ${toString desc.sourcePort}";
    sourceIPFilter = optionalString (desc.sourceIP != null) "-s ${desc.sourceIP}";
    ifFilter = optionalString (desc.interface != null) "-i ${desc.interface}";
  in ''
    ${cmd} -A nixos-fw -p ${desc.protocol} ${sourceIPFilter} ${ifFilter} ${sourcePortFilter} --dport ${toString desc.port} -j nixos-fw-accept
  '';

  extraCommands = ''
    ${concatMapStrings (desc: ipt "iptables" desc) cfg.accept}
    ${concatMapStrings (desc: ipt "ip6tables" desc) cfg.accept6}
  '';

in

{

  options.networking.firewall.accept = mkOption {
   type = pkgs.lib.types.fwRule;
   default = [];
   example = [
     { protocol = "tcp";
       port = 22;
       sourceIP = "10.0.0.0/24";
     }
     { protocol = "tcp";
       port = 80;
       interface = "eth0"; 
     }
   ];
   description = ''
     A list of filters that specify which incoming IPv4 packets should
     be accepted by the firewall.

     This option provides finer-grained control than the
     <option>networking.firewall.allowedTCPPorts</option> etc. options
     provide.
   '';
  };

  options.networking.firewall.accept6 = mkOption {
   type = pkgs.lib.types.fwRule6;
   default = [];
   example = [
     { protocol = "tcp";
       port = 22;
       sourceIP = "2001:db8::/64";
     }
     { protocol = "tcp";
       port = 80;
       interface = "eth0"; 
     }
   ];
   description = ''
     A list of filters that specify which incoming IPv6 packets should
     be accepted by the firewall.

     This option provides finer-grained control than the
     <option>networking.firewall.allowedTCPPorts</option> etc. options
     provide.
   '';
  };

  config = mkIf enable {
    networking.firewall = { inherit extraCommands; };
  };

}
