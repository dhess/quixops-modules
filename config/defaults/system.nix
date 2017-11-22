{ config, ... }:

{
  config = {
    i18n.defaultLocale = "en_US.UTF-8";
    services.logrotate.enable = true;
    sound.enable = false;
    time.timeZone = "Etc/UTC";
  };
}
