{
  programs.firefox.profiles.abaddon.search = {
    force = true;
    default = "SearXNG";
    order = [
      "SearXNG"
      "Brave"
      "Arch Wiki"
      "Gentoo Wiki"
      "GitHub"
      "Crates.io"
      "Docs.rs"
      "NixOS Options"
      "NixOS Packages"
    ];

    engines = let
      updateInterval = 24 * 60 * 60 * 1000; # Update icons once a day
    in {
      "SearXNG" = {
        urls = [{template = "https://searx.be/?preferences=eJx1WMuO6zYS_ZrxRrhGZjJAkIVXAbLNAJO9UCLLEq8oli5J2VZ_fQ71sMhW30W7rVNUsXjqSSuK3Io3HG4tO_ZkL5ZcO1HLN7J4EEWWb-wuNEVRMoyWI99akdbyxQxYV49eXvPtbz_xZeDYib7976___30JdOfA5FV3--USOx74Fkx6_-I5TDaGWlzt-FlHam5_kg180WJqCMU-2N-CMt-6qbkCl6DIfwtxhilWWqNE8-OyaqtXOJl3Uewi-5qsad2A75ta0g9yinW9mbOiPyb2c21cHU2EgsV-4-7GmQilyou1K7i-laxVK1szFFlWu_pOYs9zuGm-E8510SZQY7Edu9Y4MPt7S21dB1GGbDWwNvSv__xBY18NxnvxdX03lsOC4UAVPqsQxXMmcKTEaaprE9Ojj0bhe6J_EYe-rjf_4bEZm-IxatO2hzIZ2YHgwJkGNY6e7-wZPG2bgIEQAMJyZRK-Yk_9MHBapn_m8dNjterN9CcQvgaUPpOmyVvDhZnUuU7uOaSZP-DPepiCUcvzw5CLOH6mWuu2AvXJb0ZcyN-H1bOysjkwEzxNbzRFyrGV_IFGqMAnkAjvzYWN_35lG9-1F6MPXmGCjh3FAaGeL7NG9T4HPHMV5B6f5LnSxiOUUlCttN-9cb2h3L0tIpKuSL5tyZp91WhpTsESDhNyySBwFGQPo1mScED0-hSCyB-XO6cdReuc544aT-lj27Dj1_bNDO2Un8U4ynawBu_5uZJ7hS1apHK-TZJy9OSChSU5rSgbpEZy2yaDfHSmkD-HxuaAG3cuRM-BObMhRbfnUTJWRlI9tSbE7Z3RjMjO4xWE_jlE3uA5mA_RqqJ4DRULYbrttC4b5mDKAwceDe17vu1A4VBTCNdxRhXdyVCk9ZycP0yI8Pl9hG-dWD7hq85UH6v0saMpZcZUqzMbovSzRAmd9In5nSxUX6MRjygFMeMwprMH1dFU6MjQLbFnmeLU5B55I-80JmPnQVK6ZsseZmDJnp-mmYv8tPwipxHBnzO5EenDZ_DHJCXnCQwyeXVGR1ZLqvwEPupfglPpXAgvVz9k_kRwQpN_kGzXUwzlwj2KsqMfQpq0kYO7XLT45nDRU-zd00B27AqKtFHxQ1xZyH799bdX5nT-cDQUKSffmftz7PupmVsewh6HzP6Tu5cGh37fpz7x5CaPBFIFb-n5qy2Q7VyUlQcHJHGOIel7X7aUFTqpW-ETxwGVSMUiKR9tKhyfnDSgsRSrlhDqpngU47f4wq7s_PAF_lfWuOlVrWWId-rIOQpVSlccL2v1qa6sL6Tt3x3_ZR55JDZIBUXDWEbGmLgvmqpB1cVfdvDGuLZc4tozawta0LsgJxobE5tJ9bzTsXj_qpS66txdquN7L6naCULDrwNAmjbmst-jUkUTjlVaoNtXmAM3_YwJJDXd9wJsnv5aKRS90fPJMtnpNJmsOHuGPzkFtz8sYKTKTvwbi6hvDl7kA7vPc2Z3y-ajw_iYI85M4fAnnmOKrTXKMKNSczwchKQy37Bvj3DUnknnipehIKdnGxNO1Gx4cfQNO1G14Sj-YsnnodlR8tmqZJsk0e9RA_fDdJtB20Shm8NW47CBkSnfKcN2br4btK3jLZTEnkJWCi0Pw1ztzXEt4uX4va6YAor5T2QYIeLPZEnz2h8_i7cJKHEdTGbRx7dNlBmJhHoU2WqlCZGvfiduINwDtLif2PkWdxQ6tOIvVuj3TGVemIQnfXDoZqLDmIEwdfI-8KUhijCYphk5cCx64C7DpIPJlrahu5RjoOPMPwlCvWWOGKz36XrUqW0c7424R6WBYJOadJXjkE_6y9x2Xew_jjGaFF0NZcRinFWgBuN4mlt3I46prYhvHGNI02BmyDzuZffHE9eN3EMLUCpYoVMurfApbTwhlKsGVSzkEzeo1iae_OclxlQGMLoLZymNJoTyX_oTpVP1gunkbuW5t43QT83k4rQnWyLVYdpeu84XyRumkf0U3pEQGJGB2-ZXiR6L1J1cwL0jdPmtjzqRsuEDKOlLbeszkGJqSZVd9zDjUoU7UvW-Puiy3Gt22epldvlimin2We5Ho7ESjzcdPdLJsxlOvHamP1Y85WV6cehuVZiduHnISnz4Pl7HZ2YJCnhM18Kk9JNrH7g7Lm1-I_pJ1nbY3uXzR4z-ajJ98zQMNuMFFeVRXqITcJ42V_jcvBe4YAVV6qg_Tfxv9rvB2LfXVvbbzfEzx2gnTDvhlrLrdd2eroqsmuApWYgpREL1-kvP0-NedBIHtvfauLucJFBWY5JQ_UmSynyNOyfchwh_z2Ffm5bK5SY6KepQ9TEKb5Njsblf-lo9eQvTh5RpF9yhUNlu_wALcEfF&q={searchTerms}";}];
        definedAliases = ["@sx"];
      };

      "NixOS Packages" = {
        urls = [
          {
            template = "https://search.nixos.org/packages";
            params = [
              {
                name = "type";
                value = "packages";
              }
              {
                name = "channel";
                value = "unstable";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];

        iconUpdateURL = "https://nixos.org/favicon.png";
        inherit updateInterval;
        definedAliases = ["@np"];
      };

      "NixOS Options" = {
        urls = [
          {
            template = "https://search.nixos.org/options";
            params = [
              {
                name = "type";
                value = "packages";
              }
              {
                name = "channel";
                value = "unstable";
              }
              {
                name = "query";
                value = "{searchTerms}";
              }
            ];
          }
        ];

        iconUpdateURL = "https://nixos.org/favicon.png";
        inherit updateInterval;
        definedAliases = ["@no"];
      };

      "Crates.io" = {
        urls = [{template = "https://crates.io/search?={searchTerms}";}];
        definedAliases = ["@cr"];
      };

      "Docs.rs" = {
        urls = [{template = "https://docs.rs/releases/search?query={searchTerms}";}];
        definedAliases = ["@rs"];
      };

      "GitHub" = {
        urls = [{template = "https://github.com/search?q={searchTerms}&ref=opensearch";}];
        definedAliases = ["@gh"];
      };

      "Arch Wiki" = {
        urls = [{template = "https://wiki.archlinux.org/index.php?title=Special:Search&search={searchTerms}";}];
        definedAliases = ["@aw"];
      };
      "Gentoo Wiki" = {
        urls = [{template = "https://wiki.gentoo.org/index.php?title=Special:Search&search={searchTerms}";}];
        definedAliases = ["@gw"];
      };

      "Brave" = {
        urls = [{template = "https://search.brave.com/search?q={searchTerms}";}];
        definedAliases = ["@br"];
      };
    };
  };
}
