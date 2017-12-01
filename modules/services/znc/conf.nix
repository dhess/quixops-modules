{ lib, zncServiceConfig
}:

with lib;

let

  mkZncConf = confOpts: ''
    Version = 1.6.3
    ${lib.optionalString confOpts.hideVersion "HideVersion = true\n"}
    ${concatMapStrings (n: "LoadModule = ${n}\n") confOpts.modules}

    <Listener l>
            ${lib.optionalString (confOpts.host != "") "Host = ${confOpts.host}\n"}
            Port = ${toString confOpts.port}
            IPv4 = true
            IPv6 = true
            SSL = ${boolToString confOpts.useSSL}
    </Listener>

    <User ${confOpts.userName}>
            ${confOpts.passBlock}
            Admin = ${if confOpts.admin then "true" else "false"}
            Nick = ${confOpts.nick}
            AltNick = ${confOpts.altNick}
            Ident = ${confOpts.ident}
            RealName = ${confOpts.realName}
            ${concatMapStrings (n: "LoadModule = ${n}\n") confOpts.userModules}

            ${ lib.concatStringsSep "\n" (lib.mapAttrsToList (name: net: ''
              <Network ${name}>
                  ${concatMapStrings (m: "LoadModule = ${m}\n") net.modules}
                  Server = ${net.server} ${lib.optionalString net.useSSL "+"}${toString net.port} ${net.password}
                  ${concatMapStrings (c: "<Chan #${c}>\n</Chan>\n") net.channels}
                  ${lib.optionalString net.hasBitlbeeControlChannel ''
                    <Chan &bitlbee>
                    </Chan>
                  ''}
                  ${net.extraConf}
              </Network>
              '') confOpts.networks) }
    </User>
    ${confOpts.extraZncConf}
  '';

in
  if zncServiceConfig.zncConf != ""
    then zncServiceConfig.zncConf
    else mkZncConf zncServiceConfig.confOptions
