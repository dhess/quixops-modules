{ config, lib, ... }:

{
  config = {
    # We don't use DNSSEC.
    networking.dnsExtensionMechanism = false;

    # We don't use NixOps orchestration, we use real FQDNs, and NixOps's
    # /etc/hosts modifications screw up IPv6 DNS lookups when using
    # FQDNs.
    networking.extraHosts = lib.mkForce "";

    networking.firewall.allowPing = true;
  };
}
