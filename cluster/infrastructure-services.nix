{lib, ...}: let
  mullvadConnections = {
    deimos = {
      registeredNodeKey = "nodekey:ddec812440a7cc7728567fe2f8d6d97f5b8411fba6593fe4cdb5035c09a6aa53";
      ipv4MasqAddr = "10.139.68.25";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:b:4419";
    };
    phobos = {
      registeredNodeKey = "nodekey:b3e3b7c895bd9ff16ab73d004ae85a42c7e3aa59b71145881493196119a40324";
      ipv4MasqAddr = "10.143.70.112";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:f:4670";
    };
    phone = {
      registeredNodeKey = "nodekey:4b22be2882278b95b80bdfdb410c0cab76be7a2a0160924dde2b6a88f3a54c1e";
      ipv4MasqAddr = "10.156.52.92";
      ipv6MasqAddr = "fc00:bbbb:bbbb:bb01:d:0:1c:345c";
    };
  };

  mullvadPeer = {
    publicKey ? null,
    publicKeySecret ? null,
    endpoint,
    country,
    countryCode,
    city,
    cityCode,
    latitude,
    longitude,
    priority ? 100,
  }:
    {
      userId = 2; # demiurge
      endpoints = [endpoint];
      allowedIPs = ["0.0.0.0/0" "::/0"];
      exitNodeDNSResolvers = ["10.64.0.1"];
      suggestExitNode = true;
      tags = ["tag:mullvad" "tag:exit-node"];
      location = {
        inherit country countryCode city cityCode latitude longitude priority;
      };
      connections = mullvadConnections;
    }
    // lib.optionalAttrs (publicKey != null) {inherit publicKey;}
    // lib.optionalAttrs (publicKeySecret != null) {inherit publicKeySecret;};
in {
  laplace.services = {
    music = {
      host = "apollo";
      settings = {
        domain = "music.dysthesis.com";
        sopsFile = ../system/secrets/apollo.yaml;
      };
    };
    forgejo = {
      host = "hephaestus";
      settings = {
        domain = "git.dysthesis.com";
        frontendHost = "portunus";
      };
    };
    forgejo-runner = {
      host = "talos";
      settings = {
        instanceName = "talos";
        sopsFile = ../system/secrets/talos.yaml;
      };
    };
    observability = {
      host = "argus";
      settings = {
        domain = "observe.dysthesis.com";
        sopsFile = ../system/secrets/argus.yaml;
        expectedHosts = ["argus" "talos" "mneme" "mimir" "horos" "hermes" "charon" "loki" "hephaestus" "bifrost" "portunus"];
        writers = {
          talos = {
            certificateFingerprint = "bf7e47c79f283095d5c4675c8fbdf9be9e8b57c806a2e0583b9820cab1397034";
            role = "ci-runner";
            metricsPort = 8430;
          };
          mneme = {
            certificateFingerprint = "5510a6938727d9b1360f6481b915359a3ad028f486cedeae917ab3302d87d9bd";
            role = "photos";
            metricsPort = 8431;
          };
          mimir = {
            certificateFingerprint = "fa7365b4e32067bb3cda4bf091d8da397a01092b43c30ed2398f67d17e035d12";
            role = "apps";
            metricsPort = 8432;
          };
          horos = {
            certificateFingerprint = "7bd259022b7440a589a27716fbb4008b64686d66f71070a64311eb3e27a64f41";
            role = "notifications";
            metricsPort = 8433;
          };
          hermes = {
            certificateFingerprint = "44efa91be270f0179d193cd3913c881d55dda8c783c89377f409425325bf4385";
            role = "dns";
            metricsPort = 8434;
          };
          charon = {
            certificateFingerprint = "566364714879f02173145d77b35b329d1602f91bb5333a919bf676ca26e540d8";
            role = "exit";
            metricsPort = 8435;
          };
          loki = {
            certificateFingerprint = "e7c59c344159615ee66e3afb583aaf59d38a370413e078e2402311e9fd711bed";
            role = "game";
            metricsPort = 8436;
          };
          hephaestus = {
            certificateFingerprint = "9c254f686ca1fb96b6cc82e4216a5484df9f0808d96a2795095c1ac3e3695431";
            role = "git";
            metricsPort = 8437;
          };
          bifrost = {
            certificateFingerprint = "6ca0915346fdccfb656c6501bdcde1de53c7b94a69b9e5f8a84e9876498346ad";
            role = "control-plane";
            metricsPort = 8438;
          };
          portunus = {
            certificateFingerprint = "1aae3ff3d3c81f9c89bee547f00ce27348ceada96eeef5337564a7eeebc01a45";
            role = "edge";
            metricsPort = 8439;
          };
        };
      };
    };

    headscale = {
      host = "bifrost";
      settings = {
        domain = "headscale.dysthesis.com";
        frontendHost = "portunus";
        baseDomain = "tailnet.dysthesis.com";
        sopsFile = ../system/secrets/bifrost.yaml;
        wgOnly = {
          enable = true;
          peers = {
            mullvad-au-syd = mullvadPeer {
              publicKeySecret = "mullvad_wg_key";
              endpoint = "146.70.200.2:51820";
              country = "Australia";
              countryCode = "AU";
              city = "Sydney";
              cityCode = "syd";
              latitude = -33.8688;
              longitude = 151.2093;
            };
            mullvad-au-mel = mullvadPeer {
              publicKey = "ju0S2nDmiOrSm1H68SRTB4mtt2U8SKROprE83VCoF1Y=";
              endpoint = "163.47.16.146:51820";
              country = "Australia";
              countryCode = "AU";
              city = "Melbourne";
              cityCode = "mel";
              latitude = -37.815018;
              longitude = 144.946014;
            };
            mullvad-se-mma = mullvadPeer {
              publicKey = "cwglRdgLQ4gMG36TIYlc5OIemLNrYs4UM1KTc8mnzxk=";
              endpoint = "45.83.220.69:51820";
              country = "Sweden";
              countryCode = "SE";
              city = "Malmö";
              cityCode = "mma";
              latitude = 55.607075;
              longitude = 13.002716;
            };
            mullvad-se-sto = mullvadPeer {
              publicKey = "V5RUvv8xp3xYc9b/KoGjTL6EUEb2mTv+8egxuEvUAnc=";
              endpoint = "89.37.63.10:51820";
              country = "Sweden";
              countryCode = "SE";
              city = "Stockholm";
              cityCode = "sto";
              latitude = 59.3289;
              longitude = 18.0649;
            };
            mullvad-no-osl = mullvadPeer {
              publicKey = "QXR6DwdWn2urvyVNt5pFulLuhkyeuTp2STwGgEQ6Ehw=";
              endpoint = "141.98.253.5:51820";
              country = "Norway";
              countryCode = "NO";
              city = "Oslo";
              cityCode = "osl";
              latitude = 59.916667;
              longitude = 10.75;
            };
            mullvad-no-svg = mullvadPeer {
              publicKey = "kduYoE/b1mA2Pjszx1CzE4Lktsdc2zsUU8Relul2m2U=";
              endpoint = "194.127.199.2:51820";
              country = "Norway";
              countryCode = "NO";
              city = "Stavanger";
              cityCode = "svg";
              latitude = 58.964432;
              longitude = 5.72625;
            };
            mullvad-us-nyc = mullvadPeer {
              publicKey = "OKyEPafS1lnUTWqtVeWElkTzcmkvLi9dncBHbSyFrH8=";
              endpoint = "146.70.185.2:51820";
              country = "USA";
              countryCode = "US";
              city = "New York, NY";
              cityCode = "nyc";
              latitude = 40.73061;
              longitude = -73.935242;
            };
            mullvad-us-was = mullvadPeer {
              publicKey = "2AvJGG4MJfnJMRSR6kcha9FZMMkhJM/AtktI5DSESSI=";
              endpoint = "185.213.193.127:51820";
              country = "USA";
              countryCode = "US";
              city = "Washington DC";
              cityCode = "was";
              latitude = 38.889484;
              longitude = -77.035278;
            };
            mullvad-sg-sin = mullvadPeer {
              publicKey = "sFHv/qzG7b6ds5pow+oAR3G5Wqp9eFbBD3BmEGBuUWU=";
              endpoint = "138.199.60.2:51820";
              country = "Singapore";
              countryCode = "SG";
              city = "Singapore";
              cityCode = "sin";
              latitude = 1.293056;
              longitude = 103.855833;
            };
            mullvad-id-jpu = mullvadPeer {
              publicKey = "XYQvOrRqu8j521Hy/8+jGRDLZoSAssOvCectyKz350Y=";
              endpoint = "129.227.46.130:51820";
              country = "Indonesia";
              countryCode = "ID";
              city = "Jakarta";
              cityCode = "jpu";
              latitude = -6.17511;
              longitude = 106.865036;
            };
            mullvad-dk-cph = mullvadPeer {
              publicKey = "egl+0TkpFU39F5O6r6+hIBMPQLOa8/t5CymOZV6CC3Y=";
              endpoint = "45.129.56.67:51820";
              country = "Denmark";
              countryCode = "DK";
              city = "Copenhagen";
              cityCode = "cph";
              latitude = 55.666667;
              longitude = 12.583333;
            };
            mullvad-fi-hel = mullvadPeer {
              publicKey = "veLqpZazR9j/Ol2G8TfrO32yEhc1i543MCN8rpy1FBA=";
              endpoint = "185.204.1.203:51820";
              country = "Finland";
              countryCode = "FI";
              city = "Helsinki";
              cityCode = "hel";
              latitude = 60.192059;
              longitude = 24.945831;
            };
            mullvad-jp-osa = mullvadPeer {
              publicKey = "uhbuY1A7g0yNu0lRhLTi020kYeAx34ED30BA5DQRHFo=";
              endpoint = "194.114.136.3:51820";
              country = "Japan";
              countryCode = "JP";
              city = "Osaka";
              cityCode = "osa";
              latitude = 34.672314;
              longitude = 135.484802;
            };
            mullvad-ch-zrh = mullvadPeer {
              publicKey = "/iivwlyqWqxQ0BVWmJRhcXIFdJeo0WbHQ/hZwuXaN3g=";
              endpoint = "193.32.127.66:51820";
              country = "Switzerland";
              countryCode = "CH";
              city = "Zurich";
              cityCode = "zrh";
              latitude = 47.366667;
              longitude = 8.55;
            };
          };
        };
      };
    };
  };
}
