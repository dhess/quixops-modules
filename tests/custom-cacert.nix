{ system
, pkgs
, makeTest
, ... }:


let

  exampleCA1Pem = ''
    -----BEGIN CERTIFICATE-----
    MIIDsDCCApigAwIBAgIUb+J+7668MGVbc3oqgGTOml/pJbQwDQYJKoZIhvcNAQEL
    BQAwcDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcT
    DVNhbiBGcmFuY2lzY28xFDASBgNVBAoTC0ZvbyBDb21wYW55MR4wHAYDVQQLExVD
    ZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTcxMTI5MTAxNTAwWhcNMjIxMTI4MTAx
    NTAwWjBwMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UE
    BxMNU2FuIEZyYW5jaXNjbzEUMBIGA1UEChMLRm9vIENvbXBhbnkxHjAcBgNVBAsT
    FUNlcnRpZmljYXRlIEF1dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
    AQoCggEBAOEDx1cE06sVt7lCOojqmwQHMsSJT03W6/V8NrfDXyvyXUixIEAn+iPu
    MvbNr6JkuSLctRw4tsZCK/BgEepMUt01gixSK755mrOCNCb2ijBmK0tiYvp8jwno
    g7V4M3BcUozMD5Ez5mBpbo1OWnb6yvS64csCGGbfKH7hRU2CpvqZ9AD+GQ/suA4Q
    1RSC+JxXJfjw3aMr8goNOQAyPjrDZEIGZ0K20BhDZAb8v3yZ8ZaQbXq5xE9TaCDw
    ZJiQ5PjCQ4yNEWyc2iPFX091XinTN6dr0BD3+Cp7kVVZVCCBq/8gT5nbC5saUHJf
    FZu3bk0DLFrLxXKyesQ/20SWtGLGOJkCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgEG
    MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFMnX3yF993aswclyaHwFsO8X0dQX
    MA0GCSqGSIb3DQEBCwUAA4IBAQCDBlRN0HJXOa7exyy6huNyN/lIUAvP4SDRBrHr
    cYfjMgqvPRzLSxiBFOcoG8BhExp68w1zSyyfuroqHDvh0FaUV7p1pqUVdw2fDiqW
    /238gtJP7MpUU4oXVEmvJhsGv3aboaiXYw3iCzJjXFXI5ypZybm3bdbxBWMcspw9
    A6ZbOTxtteDEojm0GEuxkkLGCMXjA3EVdjleByxAA6nFQGVZiFSShrPQoXlckuBx
    mnHp9wHIMLSp4KUtZ9IBmpyxLrSYwGJUzmydoVmc/MjDutEEC6Pt3SRZbRO/eWSP
    CIu9OpGQEqT2npTMX2echilaFjlKB3D3X91sgJ7Z0v2KrDz8
    -----END CERTIFICATE-----
  '';

  exampleCA2Pem = ''
    -----BEGIN CERTIFICATE-----
    MIIDsDCCApigAwIBAgIUUS0WI3pOMA8M6VgkMR+MI2Lq9aEwDQYJKoZIhvcNAQEL
    BQAwcDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcT
    DVNhbiBGcmFuY2lzY28xFDASBgNVBAoTC0JhciBDb21wYW55MR4wHAYDVQQLExVD
    ZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTcxMTI5MTAyMzAwWhcNMjIxMTI4MTAy
    MzAwWjBwMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UE
    BxMNU2FuIEZyYW5jaXNjbzEUMBIGA1UEChMLQmFyIENvbXBhbnkxHjAcBgNVBAsT
    FUNlcnRpZmljYXRlIEF1dGhvcml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCC
    AQoCggEBAMBrkCmR21lU7xULou8C4N7/ovj2yR+DdnK0WjPmNA8pAGCYMQQiyxG0
    dy571TMoHCBdew2A1lJ1MNWcIBtxqnE9Gcfgiu2DeVV2pZa8EcPqMwRnXIs3DQNf
    yI7yZ7Q/vQ0ivG5GvdkFW+5riAXisD6VsDxf80lB9p9q4Am/c1mtf1PRDu+2YkaL
    9KGRmYFlQWc/Gxg6js+MATdq20SIZStjiGtzBm621de4uNNs3dGqjuyTtmJ8j+X6
    4A3Zeov6j94wpFhlSa1GMQU+keyR9HhbSuKhT6iKzCi+Ezr4K+Kme70AWWubTJA2
    9E8/izgQGFAnYTjuK0QfXsj0XMDZtmsCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgEG
    MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFP4dIbCzFP/fqsmwmgp1iY01WAKk
    MA0GCSqGSIb3DQEBCwUAA4IBAQAfTgtgWhZsTDBeKnqCU69aAa3H9lFNt6er20bw
    FXDABBkMPwFBtyUm+MaQTomRiZzNQah7Jw1P7FT2unq56hnEabK8X+UEG0ZcuuLa
    XzAHGOYm/2D1w81KE4ujT+V99wbceJ8BXTfgKYs6XNUX6FTTPBe8aPswwa3oyL7s
    HciTf/eOmNEn4Z2hACvYhPbjfGdBn9OrGGIgLnBOzAX+SpIFC/KWqqSEUoHjKWNI
    fUvO71qrRkGpEZHkKyb0zYDGbdJJRdqvBcyakBSHqcX3WnB1QV3W42GIT6WfFh+r
    YZD9l4zI7ZoVAjSDMio1kZrhKmkEiejHaLV32xJFEweaf2+c
    -----END CERTIFICATE-----
  '';

  extraCerts = {
    "Example CA 1" = exampleCA1Pem;
    "Example CA 2" = exampleCA2Pem;
  };

  server1Pem = pkgs.writeText "server1.pem" ''
    -----BEGIN CERTIFICATE-----
    MIID8TCCAtmgAwIBAgIUdj0L3zecvezJnwb6BxuKdzhHgtwwDQYJKoZIhvcNAQEL
    BQAwcDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcT
    DVNhbiBGcmFuY2lzY28xFDASBgNVBAoTC0ZvbyBDb21wYW55MR4wHAYDVQQLExVD
    ZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTcxMTI5MTAxNzAwWhcNMTgxMTI5MTAx
    NzAwWjBeMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UE
    BxMNU2FuIEZyYW5jaXNjbzEUMBIGA1UEChMLRm9vIENvbXBhbnkxDDAKBgNVBAsT
    A1dXVzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAJKLTKU3EHm61LPN
    MLi+gD3ZwyEKTZ9BTyxmBXev5MN0ZkODBCGcas+3NdWn3N9VxqxfYPoT71nbr6ea
    SkNpujW0FVxkjkjiWYsgT0X6N5mgH5hY5mYG5olYDLMtZBSeN5tFWSylu8OTUf6f
    YOkOAloylf1g/Shwk/pAFccAm3+xSjl21S9/IFxNyz6aUrh6JocxG7r1F/VBDabz
    6262fITeEJejlDiwDfEnpC1qOj8/hi7OgLEjEQ9RFbgbIfGwCz2MYi8hVkJFDou4
    z7N6uBKBMTNCtU+/Ty5CPt9jeIo90Wa6ljAa5lRY4BR0JpapXYZYMTLbu6Y5QFFB
    ZM425ucCAwEAAaOBlDCBkTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYB
    BQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFBZXN0ClUkL+
    tBcXwQvpepl4EjlLMB8GA1UdIwQYMBaAFMnX3yF993aswclyaHwFsO8X0dQXMBIG
    A1UdEQQLMAmCB3NlcnZlcjEwDQYJKoZIhvcNAQELBQADggEBAEMq6m5ppMi9WURm
    ZY4i8GNzFUF4hs7KAruOmuyDzEaBnJT5fYZq+lmMk6MS3FsKx6+QuT/0yufJzrqP
    q+vuTW11EUgiqgvWHcOgARHY0gcY9+Mv+hsB239RreCNVi7Y9Wmx3YDQNd5pzVFv
    O+1acKn7gDJOiuosvXWEdrY0XH9O3Mndbtw90nI0Gj1a3s74xhfp8DbNilwVetyc
    fo9sumZafCkthFbofag36cnznXuY/SJJMGUzE8RMU1ztMfoTjz8OwW00GPgHbaAy
    XYMRssS2T8Da8zHU6j8JKvvc16lA/LEqUZPQqtU6MhxKmuMYM4pLFqjv37BKNkhj
    dN6RX7s=
    -----END CERTIFICATE-----
  '';

  server1Key = pkgs.writeText "server1.key" ''
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEAkotMpTcQebrUs80wuL6APdnDIQpNn0FPLGYFd6/kw3RmQ4ME
    IZxqz7c11afc31XGrF9g+hPvWduvp5pKQ2m6NbQVXGSOSOJZiyBPRfo3maAfmFjm
    ZgbmiVgMsy1kFJ43m0VZLKW7w5NR/p9g6Q4CWjKV/WD9KHCT+kAVxwCbf7FKOXbV
    L38gXE3LPppSuHomhzEbuvUX9UENpvPrbrZ8hN4Ql6OUOLAN8SekLWo6Pz+GLs6A
    sSMRD1EVuBsh8bALPYxiLyFWQkUOi7jPs3q4EoExM0K1T79PLkI+32N4ij3RZrqW
    MBrmVFjgFHQmlqldhlgxMtu7pjlAUUFkzjbm5wIDAQABAoIBACg/J7KsV9MG08n5
    zaq/bxsNhoC5gq39UtA/yLqhTTO88SUTg3vzqIYZrChcrNWNij3nCAxGk1LbefeO
    8VxoWiLLrZ4tY8Jyn+MM4Zi3arO/fU3rBIP62y/XRc2j5rue5Gi5eA9CCTpiaH+E
    qCn5lf3NrNHk5EJKAOoW1aRM72f3D6ZTIUcGbiTuHh7J0wQZ/MFseD+1iBSgJZmd
    fRz3P5X+WVu1cB1Hw61n8JiKbv0zEkM8J+TJ28Xo44k2zpytTnXmeDh5fRp7KW8Y
    BarpSUncIsMoOaHwv3YirI1B0Twhn8k2XpQAZRpdludx7ETYuPS6DEI+RJsbA28e
    dEifW2kCgYEAwNFIUAv384n2axMMBOjHbUXT9llhHw8DNgzaLWAyba+agcu5M+Pt
    l9ADM6DjD32Wfb/HfJDPDWBUbPcUPddA7K0yNH2D3uvqEcGn/xn1QDXnQZwmWBMy
    D1lKYN0PtJgjcIDs+sxb7A1eD1COFTF+EhOfCB2CGb3GBzVn3EwQUI0CgYEAwpBS
    e0QLxhkRkYLX4eNeVy6LKYDX4+Ai/GZ4QhjAU8TAfNxKA6wTj8kM6i1jzRMg+7bG
    zCGODO6KSR30iBZz6Rxg+bH9MWrceZe1sP9CXHdT0mLiUrWKoGhm7Mmr9I+KIUCD
    66i2uhBTOM5a5lwRBxJcwPeAtIjrZl1R4fSxmkMCgYAn2RiAsniDtDdg2YbaXOEa
    DBxKBR61NH0NZoqQZhkF4gykVl3oA2rOvQZsXQuP3/yB8GhhreuccBQCkO11+k5I
    m2KMxoPCRi8RjFwTtGGi64DnZkXmXdEyqtlcO1NLl0V7sqlHC4TTu898isFST/Al
    /DgZjT+d4kJSqw7T0ERu4QKBgQCZ+lHsj+upeUl4GU70zFZrNMCZtgglpcrKaeYe
    mSwMn5eeuVAyG8rXbku0QPvM3qipzPsDrkKXZWk3eGeAFBTjlbwBoKU6qNGXwULf
    swQ33ZAO3ocy4c22KSnbl7dosvikXESLCliiZC0YtecmjBJFwHh7luTa+8kgmBYn
    dtnftQKBgQCJ2Tvfr6Dz0MGhkw4UHd3yHNmIO4ltI8nhqQm5H39IGmdozBM74aro
    /Se10pE1Dky0/uo7gA9vcEufxXCjIb0q4QvBPQ+SBo1xL4QpWsiyB7jFGqr6/Tie
    gnK6FH1Gxkquo9AnV8KGXJQ9AOllUkgv+Zg2G1bIEcgqbGIfuOo79g==
    -----END RSA PRIVATE KEY-----
  '';

  server2Pem = pkgs.writeText "server2.pem" ''
    -----BEGIN CERTIFICATE-----
    MIID8TCCAtmgAwIBAgIUcTA8GW92gu/JDdWDDv3XFc3rPz4wDQYJKoZIhvcNAQEL
    BQAwcDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCkNhbGlmb3JuaWExFjAUBgNVBAcT
    DVNhbiBGcmFuY2lzY28xFDASBgNVBAoTC0JhciBDb21wYW55MR4wHAYDVQQLExVD
    ZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMTcxMTI5MTAyMzAwWhcNMTgxMTI5MTAy
    MzAwWjBeMQswCQYDVQQGEwJVUzETMBEGA1UECBMKQ2FsaWZvcm5pYTEWMBQGA1UE
    BxMNU2FuIEZyYW5jaXNjbzEUMBIGA1UEChMLQmFyIENvbXBhbnkxDDAKBgNVBAsT
    A1dXVzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALKHJneJmSvHcGj5
    ejNbB16NSQypFlGpy2cbH+DwNjkrZPit2AsuyrE3lPqrm7ZaBVCK5Fjui7Q1UAxV
    Cvq71gGvtHM5hBYPYbKTZLoeO/IDyzh0Zg8Xt2+7bCzsD1Eev51HrYD5TPOh1jD2
    QKoR0q7ShpXWReBwZWkbtyinyb7+nTud14mwZnowjydRFZkx0rbbxkJCIPkJZS5n
    cvT9iKEpIcVRPs4bhuCEj1yW2Mu9mFRo9QPaBejc5Tk7dDctba4aHspUsqv6fIK8
    4CIm6H0dV8I5eVHXkdXpUR/6YEe2XU3Ixo4bN/4DddnT5cBfLDuXFmnUHk2eVNa7
    o5mdIXUCAwEAAaOBlDCBkTAOBgNVHQ8BAf8EBAMCBaAwHQYDVR0lBBYwFAYIKwYB
    BQUHAwEGCCsGAQUFBwMCMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFFafvXHbXoY7
    s2SWKXP09KAhfTHLMB8GA1UdIwQYMBaAFP4dIbCzFP/fqsmwmgp1iY01WAKkMBIG
    A1UdEQQLMAmCB3NlcnZlcjIwDQYJKoZIhvcNAQELBQADggEBACrWlVz35OYVwdz0
    gJ/Ehchdgs62pufNOonoOpIF/X69KW+As5jUHkZPgMyLGmtPbwOvLGzIZeb5XhFP
    vaqGzZ1N1T42AHQsDHMNS78Hs86LpGJa1ucZAy2m8J3NL4dAZ5ezQNFebsmDII83
    PZdzDfGw4V4zdTrsKDfTZ1wTCdDIU6OKujK1HSDZy4e/x7PsLBs/fIC8r9IUeKLD
    2xSNKqci7f1Y2ITZIvbOZYUeWIWelrYo1/Af3IUNwore2GrlbJumwxHBvwQfk5qN
    iOtc0UMGWYAr93pW7vndxNN1O8JrPo7vkc4Mwq1HFZskQ8rzQDJyQIWty+6BftS/
    RXKX6NY=
    -----END CERTIFICATE-----
  '';

  server2Key = pkgs.writeText "server2.key" ''
    -----BEGIN RSA PRIVATE KEY-----
    MIIEowIBAAKCAQEAsocmd4mZK8dwaPl6M1sHXo1JDKkWUanLZxsf4PA2OStk+K3Y
    Cy7KsTeU+qubtloFUIrkWO6LtDVQDFUK+rvWAa+0czmEFg9hspNkuh478gPLOHRm
    Dxe3b7tsLOwPUR6/nUetgPlM86HWMPZAqhHSrtKGldZF4HBlaRu3KKfJvv6dO53X
    ibBmejCPJ1EVmTHSttvGQkIg+QllLmdy9P2IoSkhxVE+zhuG4ISPXJbYy72YVGj1
    A9oF6NzlOTt0Ny1trhoeylSyq/p8grzgIibofR1Xwjl5UdeR1elRH/pgR7ZdTcjG
    jhs3/gN12dPlwF8sO5cWadQeTZ5U1rujmZ0hdQIDAQABAoIBABjInlR166eiNj68
    c3RxrKI5pux1BL4tfilAILrPXhetqITFTXqv8j+L4ciyzhkQgjBeN7kI1KgdxpEP
    tUh9jwYI6Foen/GYDQ4HXDJiRBwi3rFlp01tE3AVar0JwE6YoC0raDDBaydfTibZ
    6LwzYTYXz8s5RdYUhF+FE3Y3ZNB4uOOEnoiutFJcBWWS5r+ZxsdPdDiMtcIr/y8u
    uNr59WezvzD5RkxvoPNUHXTp/66MTL91WX6/AT66zfAPjStyw4ZiqszQAY60plkH
    JGVAjluQk1pQq3G+NmnIHfRSd0cNGtJ/TKYMjJ8v6bC8OjFTCP7SEmQWgCNkfDTc
    SyaSM7kCgYEAzs0LyksPRo42iE0hx8tIR4dFkQgbVywb7pv9Vtnu59LJxNrdB9kA
    ehwcqmrs39hIPwEAeuSj82YMQif5j7v+Qr5Mi7YTe+iGOdZuqPgT256rMw9+SaDT
    FduZPwarGUUiLeMC99dsLa2NSv4Es8qpcis/V+Ble1Iz3F0/4MKvUvsCgYEA3QAr
    rx1HctfDjvB2M+c4xRA8ArDslxInchfKn0s04po6ehpU8hVpAnEWVAEK61+CT+87
    4SkodChSVanWFtH2wG4UyWZzkhRfk9UQU/d0lnXqNfMqrRAiP/zUjVTIHQqr/lsD
    D1Y/w3hYp2+JVJUMm63F9IBKVQruOWhOHvBwsk8CgYEAlBcL0WJs3vaqIHMztJJj
    AS3iaFho08T3f6hfA9nulj5BVOHyFFOWXttQv8zwMd/85HlAMcEXkw5Jyvo7YW2b
    R4pk4EuTqlC6BiMDfaag+c2nBVqb8ffkESv/kr2guujh8AA3uOmgQxmcK8656VJA
    g0xrAO/lXClij/SK8NYZnQ8CgYA0VfYCYkypRa9qCkfzwq4O/Ok5OezNWd89haTW
    VFkR0LRIdjPnoGpdyaof+p87XkLd6ymjCLwrxeC5qJ6qiM6Gg4soprp3vZtkxvA2
    8kMJ3qK4Y/2XPlreDGHJlmpNdlmEwsjWuPYgtD9KZ39+KE30EBLw8/CmcxA3SBw3
    93i4wQKBgFMarJjOU3Zb1bkQR5LfYD6xHj/NCHW9CmVyQPzuKf2ziqc9LlraqZ7l
    0Zof32T3Cvo4nqCOy0UcNizgttXYMp/SXsvzm6Eco7/xkCWIBia9cj4yx5XmgoEl
    uMTYaXZZ3Wxpl5eV8CicJZ9BHme1rzJLV/KpNvhvjR/v7abUxaT0
    -----END RSA PRIVATE KEY-----
  '';

  makeMkCacertTest = name: clientAttrs:
    makeTest {
      name = "mkCacert-${name}";
      meta = with pkgs.lib; {
        maintainers = [ maintainers.dhess-qx ];
      };

      nodes = {

        client = { config, ... }: {
          imports = (import pkgs.lib.quixops.modulesPath);
        } // clientAttrs;

        server1 = { config, ... }: {
          networking.firewall.allowedTCPPorts = [ 443 ];
          services.nginx = {
            enable = true;
            virtualHosts."server1" = {
              forceSSL = true;
              sslCertificate = server1Pem;
              sslCertificateKey = server1Key;
              locations."/".root = pkgs.runCommand "docroot" {} ''
                mkdir -p "$out"
                echo "<!DOCTYPE html><title>server1</title>" > "$out/index.html"
              '';
            };
          };
        };

        server2 = { config, ... }: {
          networking.firewall.allowedTCPPorts = [ 443 ];
          services.nginx = {
            enable = true;
            virtualHosts."server2" = {
              forceSSL = true;
              sslCertificate = server2Pem;
              sslCertificateKey = server2Key;
              locations."/".root = pkgs.runCommand "docroot" {} ''
                mkdir -p "$out"
                echo "<!DOCTYPE html><title>server2</title>" > "$out/index.html"
              '';
            };
          };
        };
        
      };

      testScript = { nodes, ... }:
      let
        custom-cacert = pkgs.lib.mkCacert { inherit extraCerts; };
      in
      ''
        startAll;
        $server1->waitForUnit("nginx.service");
        $server2->waitForUnit("nginx.service");
        $client->waitForUnit("multi-user.target");

        subtest "default-cacert-fails", sub {
          $client->fail("${pkgs.wget}/bin/wget -O server1.html https://server1");
          $client->fail("${pkgs.wget}/bin/wget -O server2.html https://server2");
        };

        subtest "custom-cacert-succeeds", sub {
          $client->succeed("${pkgs.wget}/bin/wget -O server1.html --ca-certificate=${custom-cacert}/etc/ssl/certs/ca-bundle.crt https://server1");
          $client->succeed("${pkgs.wget}/bin/wget -O server2.html --ca-certificate=${custom-cacert}/etc/ssl/certs/ca-bundle.crt https://server2");
        };
      '';
    };

in
{

  defaultTest = makeMkCacertTest "default" { };

}
