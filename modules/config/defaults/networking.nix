{ config, lib, ... }:

{
  config = {
    # We don't use DNSSEC.
    networking.dnsExtensionMechanism = false;
    networking.firewall.allowPing = true;
  };
}
