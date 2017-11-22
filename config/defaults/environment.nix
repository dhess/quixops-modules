{ config, pkgs, ... }:

{
  config = {
    environment.systemPackages = with pkgs; [
      git
      wget
    ];

    environment.shellAliases = {
      l = "ls -F";
      ll = "ls -alF";
      ls = "ls -F";
      ltr = "ls -alFtr";
      m = "more";
      more = "less";
      mroe = "less";
      pfind = "ps auxww | grep";
    };

    # Disable HISTFILE globally.
    environment.interactiveShellInit =
      ''
        unset HISTFILE
      '';

    environment.noXlibs = true;

    programs.bash.enableCompletion = true;
  };
}
