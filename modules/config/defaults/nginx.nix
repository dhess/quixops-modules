{ config, pkgs, lib, ... }:

with lib;

let

  cfg = config.quixops.defaults.nginx;
  enabled = cfg.enable;
  nginx_enabled = config.services.nginx.enable;

in
{
  options.quixops.defaults.nginx = {

    enable = mkEnableOption ''
      Enable the Quixops nginx configuration defaults. These include
      NixOS-recommended compression, proxy, optimization, and TLS
      settings. It also enables the Mozilla-recommended "modern" SSL
      ciphers for server-side SSL, disables all TLS versions other
      than TLS v1.2, and enables perfect forward secrecy via DH
      parameters, which are generated on first use. In addition,
      nginx's server tokens are disabled.

      Note that enabling this option does not enable the nginx
      service itself; it simply ensures that any nginx services you
      run on this host will be configured with these default
      settings.
    '';

  };

  config = mkIf enabled {

    services.nginx = {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedTlsSettings = true;
      recommendedProxySettings = true;

      serverTokens = false;

      # Mozilla recommendation.
      sslCiphers = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256";

      sslProtocols = "TLSv1.2";
    };

  };

}
