{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.laplace.services.miniflux.enable;
  inherit
    (lib)
    mkIf
    ;

  minifluxPackage = pkgs.miniflux.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace internal/template/functions.go \
          --replace-fail $'"require-trusted-types-for": "\'script\'",' "" \
          --replace-fail $'"style-src":                 "\'nonce-" + nonce + "\'",' $'"style-src":                 "\'self\' \'nonce-" + nonce + "\'",' \
          --replace-fail '"trusted-types":             "html url",' $'"style-src-attr":            "\'unsafe-inline\'",\n\t\t"font-src":                  "\'self\'",\n\t\t"trusted-types":             "html url miniflux-enhancements",' \
          --replace-fail 'if user != nil {' $'if user == nil || user.CustomJS == "" {\n\t\tpolicies["require-trusted-types-for"] = "\'script\'"\n\t}\n\n\tif user != nil {' \
          --replace-fail 'policies["font-src"] = user.ExternalFontHosts' 'policies["font-src"] += " " + user.ExternalFontHosts'

        substituteInPlace internal/template/functions_test.go \
          --replace-fail $'`style-src \'nonce-1234\';`' $'`style-src \'self\' \'nonce-1234\';`' \
          --replace-fail $'`style-src \'nonce-1234\' test.com;`' $'`style-src \'self\' \'nonce-1234\' test.com;`' \
          --replace-fail '`trusted-types html url;`' '`trusted-types html url miniflux-enhancements;`' \
          --replace-fail $'\t\t`require-trusted-types-for \'script\';`,\n' "" \
          --replace-fail '`font-src test.com;`' $'`font-src \'self\' test.com;`'
      '';
  });

  # KaTeX assets and bootstrap script that stay in the Nix store.
  katexInit =
    pkgs.writeText "miniflux-katex-init.js"
    # js
    ''
      try {
        const nonce = document.currentScript?.nonce || "";
        const base = window.location.origin + "/katex";

        const ensureCss = () => {
          if (document.querySelector('link[data-katex-css="1"]')) return;
          const link = document.createElement("link");
          link.rel = "stylesheet";
          link.href = base + "/katex.min.css";
          link.setAttribute("data-katex-css", "1");
          if (nonce) link.nonce = nonce;
          document.head.append(link);
        };

        let rendererPromise;
        const getRenderer = () => {
          if (!rendererPromise) {
            rendererPromise = import(base + "/contrib/auto-render.mjs").then((mod) => mod.default);
          }
          return rendererPromise;
        };

        const renderElement = async (el) => {
          if (!el || el.dataset.katexRendered === "1") return;
          el.dataset.katexRendered = "1";
          ensureCss();
          const renderMathInElement = await getRenderer();
          renderMathInElement(el, {
            delimiters: [
              { left: "$$", right: "$$", display: true },
              { left: "$", right: "$", display: false },
              { left: "\\[", right: "\\]", display: true },
              { left: "\\(", right: "\\)", display: false }
            ],
            throwOnError: false
          });
          el.querySelectorAll(".katex-mathml").forEach((n) => {
            n.setAttribute("aria-hidden", "true");
            n.style.position = "absolute";
            n.style.width = "1px";
            n.style.height = "1px";
            n.style.overflow = "hidden";
            n.style.clip = "rect(1px, 1px, 1px, 1px)";
            n.style.whiteSpace = "nowrap";
          });
        };

        const handleNode = (node) => {
          if (node?.nodeType !== Node.ELEMENT_NODE) return;
          if (node.classList.contains("entry-content")) {
            void renderElement(node);
          } else {
            node.querySelectorAll?.(".entry-content").forEach((el) => void renderElement(el));
          }
        };

        document.querySelectorAll(".entry-content").forEach(handleNode);

        const observer = new MutationObserver((mutations) => {
          for (const mutation of mutations) {
            mutation.addedNodes.forEach(handleNode);
          }
        });
        observer.observe(document.body, { subtree: true, childList: true });
      } catch (err) {
        console.error("KaTeX bootstrap failed", err);
      }
    '';

  # Highlight.js assets and bootstrap script that stay in the Nix store.
  highlightInit = pkgs.writeText "miniflux-highlight-init.js" ''
    (function() {
      "use strict";

      const base = window.location.origin + "/highlight";
      let hljsLoaded = false;
      let hljsLoading = false;

      function loadCSS() {
        if (document.querySelector('link[data-highlight-css="1"]')) return;
        const link = document.createElement("link");
        link.rel = "stylesheet";
        link.href = base + "/styles/default.min.css";
        link.setAttribute("data-highlight-css", "1");
        document.head.appendChild(link);
      }

      function loadHighlightJs(callback) {
        if (hljsLoaded) {
          callback();
          return;
        }

        if (hljsLoading) {
          // Wait for existing load
          const checkLoaded = setInterval(() => {
            if (hljsLoaded) {
              clearInterval(checkLoaded);
              callback();
            }
          }, 50);
          return;
        }

        hljsLoading = true;
        const script = document.createElement("script");
        script.src = base + "/highlight.min.js";
        script.onload = () => {
          hljsLoaded = true;
          hljsLoading = false;
          callback();
        };
        script.onerror = () => {
          hljsLoading = false;
          console.error("Failed to load highlight.js");
        };
        document.head.appendChild(script);
      }

      function highlightElement(el) {
        if (!el || el.dataset.highlightRendered === "1") return;
        el.dataset.highlightRendered = "1";

        loadCSS();
        loadHighlightJs(() => {
          if (window.hljs) {
            el.querySelectorAll("pre code").forEach((block) => {
              window.hljs.highlightElement(block);
            });
          }
        });
      }

      function handleNode(node) {
        if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
        if (node.classList && node.classList.contains("entry-content")) {
          highlightElement(node);
        } else if (node.querySelectorAll) {
          node.querySelectorAll(".entry-content").forEach(highlightElement);
        }
      }

      // Highlight existing content
      document.addEventListener("DOMContentLoaded", () => {
        document.querySelectorAll(".entry-content").forEach(highlightElement);
      });

      // Watch for dynamically added content
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          mutation.addedNodes.forEach(handleNode);
        });
      });

      if (document.body) {
        observer.observe(document.body, { subtree: true, childList: true });
      } else {
        document.addEventListener("DOMContentLoaded", () => {
          observer.observe(document.body, { subtree: true, childList: true });
        });
      }
    })();
  '';

  katexAssets = pkgs.runCommand "katex-miniflux-assets" {} ''
    mkdir -p "$out"
    cp -r ${pkgs.katex}/lib/node_modules/katex/dist/. "$out"/
    cp ${katexInit} "$out"/miniflux-init.js
  '';

  highlightJsCore = pkgs.fetchurl {
    url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.10.0/highlight.min.js";
    sha256 = "sha256-Rx75rpDEB69ED83Ejt/utWIQazJnvRLZkHHBYvtS7TI=";
  };

  highlightJsCss = pkgs.fetchurl {
    url = "https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.10.0/styles/default.min.css";
    sha256 = "sha256-+94KwJIdhsNWxBUy5zGciHojvRuP8ABgyrRHJJ8Dx88=";
  };

  highlightAssets = pkgs.runCommand "highlight-miniflux-assets" {} ''
    mkdir -p "$out/styles"

    cp ${highlightJsCore} "$out/highlight.min.js"
    cp ${highlightJsCss} "$out/styles/default.min.css"
    cp ${highlightInit} "$out"/miniflux-init.js
  '';
in {
  config = mkIf cfg {
    # Tell sops-nix that this should be found in the default sops file.
    sops.secrets.miniflux_admin = {};

    services.miniflux = {
      enable = true;
      package = minifluxPackage;
      config = {
        LISTEN_ADDR = "127.0.0.1:8087";
        BASE_URL = "http://localhost:8085";
        CLEANUP_FREQUENCY = "168";
        FETCHER_ALLOW_PRIVATE_NETWORKS = "1";
      };
      adminCredentialsFile = config.sops.secrets.miniflux_admin.path;
    };

    virtualisation.oci-containers.containers."full-text-rss" = {
      autoStart = true;
      image = "heussd/fivefilters-full-text-rss:latest";
      ports = ["127.0.0.1:7756:80"];
    };

    laplace.docker.enable = true;

    services.nginx = {
      enable = true;
      recommendedProxySettings = false;
      commonHttpConfig = ''
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header Connection "";
      '';

      virtualHosts."localhost" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 8085;
          }
        ];
        locations = {
          "/" = {
            proxyPass = "http://127.0.0.1:8087/";
            proxyWebsockets = true;
          };
          "/katex/" = {
            alias = "${katexAssets}/";
            extraConfig = ''
              autoindex off;
              add_header Cache-Control "public, max-age=31536000, immutable";
            '';
          };
          "/highlight/" = {
            alias = "${highlightAssets}/";
            extraConfig = ''
              autoindex off;
              add_header Cache-Control "public, max-age=31536000, immutable";
            '';
          };
        };
      };
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/miniflux 0750 postgres postgres -"
    ];

    users = {
      groups.miniflux = {};
      users.miniflux = {
        isSystemUser = true;
        group = "miniflux";
      };
    };
  };
}
