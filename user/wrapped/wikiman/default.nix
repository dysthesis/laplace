{
  pkgs,
  lib,
  ...
}: let
  fetchWikimanSource = {
    name,
    version ? "2.14.1",
    url,
    sha256,
  }:
    pkgs.stdenv.mkDerivation {
      pname = "wikiman-source-${name}";
      inherit version;
      src = pkgs.fetchurl {inherit url sha256;};

      dontBuild = true;

      installPhase =
        ''
          set -euo pipefail
          runHook preInstall

          mkdir -p "$out/share"

          if [ -d usr/share ]; then
            cp -R usr/share/* "$out/share/"
          elif [ -d share ]; then
            cp -R share/* "$out/share/"
          else
            echo "Unexpected archive layout; neither usr/share nor share present"
            find . -maxdepth 2 -type d -print
            exit 1
          fi
        ''
        + lib.optionalString (name == "tldr") ''
          tl="$out/share/doc/tldr-pages"
          if [ -L "$tl/en/pages.en" ]; then
            rm -f "$tl/en/pages.en"
            if [ -d "$tl/pages" ]; then
              ln -s ../pages "$tl/en/pages.en"
            elif [ -d "$tl/pages.en" ]; then
              ln -s ../pages.en "$tl/en/pages.en"
            else

              :
            fi
          fi
        ''
        + ''
          runHook postInstall
        '';

      meta = with lib; {
        description = "Wikiman source data (${name}) from upstream releases";
        platforms = platforms.unix;
      };
    };

  arch = fetchWikimanSource {
    name = "arch";
    url = "https://github.com/filiparag/wikiman/releases/download/2.14.1/arch-wiki_20250710.source.tar.xz";
    sha256 = "sha256-tyGZGt41swQr/3zLTEN1pT7vSfVBgjuM9n+l0GOs0gM=";
  };

  tldr = fetchWikimanSource {
    name = "tldr";
    url = "https://github.com/filiparag/wikiman/releases/download/2.14.1/tldr-pages_20250710.source.tar.xz";
    sha256 = "sha256-lejTQHkwqkt5VJjlM5znF+7VoreB8Cfju+B3I5C+/kM=";
  };

  gentoo = fetchWikimanSource {
    name = "gentoo";
    url = "https://github.com/filiparag/wikiman/releases/download/2.14.1/gentoo-wiki_20250710.source.tar.xz";
    sha256 = "sha256-Xcnk4KEUB+gzhyu1D5zlrP4dp7qTEDWaBc8b+7y8mBU=";
  };

  freebsd = fetchWikimanSource {
    name = "freebsd";
    url = "https://github.com/filiparag/wikiman/releases/download/2.14.1/freebsd-docs_20250710.source.tar.xz";
    sha256 = "sha256-/y4nmx1Appchvf59r2HA1PksdWCcAaypLug56QNYLlM=";
  };

  wikimanConf = pkgs.writeText "wikiman.conf" ''


    sources = man arch gentoo fbsd tldr

    fuzzy_finder = fzf
    man_lang = en
    wiki_lang = en
    tui_html = w3m
  '';

  inner = pkgs.writeShellScript "wikiman-inner" ''
    set -euo pipefail


    export HOME=/tmp/wikiman-home
    mkdir -p "$HOME/.parallel"
    : > "$HOME/.parallel/will-cite"
    chmod 600 "$HOME/.parallel/will-cite"


    mkdir -p "$HOME/.config/wikiman"
    cp ${wikimanConf} "$HOME/.config/wikiman/wikiman.conf"


    test -d /usr/share/doc/arch-wiki/html || echo "warn: /usr/share/doc/arch-wiki/html missing" >&2
    test -d /usr/share/doc/freebsd-docs   || echo "warn: /usr/share/doc/freebsd-docs   missing" >&2
    test -d /usr/share/doc/gentoo-wiki    || echo "warn: /usr/share/doc/gentoo-wiki    missing" >&2
    test -d /usr/share/doc/tldr-pages     || echo "warn: /usr/share/doc/tldr-pages     missing" >&2

    exec env \
      conf_sys_usr=/usr \
      conf_sys_etc=/etc/xdg/wikiman \
      ${pkgs.wikiman}/bin/.wikiman-wrapped "$@"
  '';
in
  pkgs.writeShellApplication {
    name = "wikiman";
    runtimeInputs = with pkgs.unstable; [
      wikiman
      gawk
      coreutils
      findutils
      fzf
      gnugrep
      man-db
      parallel
      ripgrep
      gnused
      w3m
      bubblewrap
      glibcLocales
    ];
    text = ''
      set -euo pipefail


      export LANG="en_AU.UTF-8"
      export LC_ALL="en_AU.UTF-8"
      export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"


      export PARALLEL="--will-cite"


      export TMPDIR=/tmp
      export TEMP=/tmp
      export TMP=/tmp


      export PATH="${lib.makeBinPath [
        pkgs.wikiman
        pkgs.coreutils
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gawk
        pkgs.ripgrep
        pkgs.fzf
        pkgs.gnused
        pkgs.w3m
        pkgs.man-db
        pkgs.parallel
      ]}"


      for p in \
        "${arch}/share/doc/arch-wiki" \
        "${tldr}/share/doc/tldr-pages" \
        "${gentoo}/share/doc/gentoo-wiki" \
        "${freebsd}/share/doc/freebsd-docs"
      do
        [ -d "$p" ] || { echo "missing: $p" >&2; exit 1; }
      done

      exec ${pkgs.bubblewrap}/bin/bwrap \
        --dev /dev --proc /proc \
        --ro-bind /nix/store /nix/store \
        --dir /bin \
        --ro-bind ${pkgs.bash}/bin/bash /bin/sh \
        --tmpfs /tmp \
        --tmpfs /usr --dir /usr/share --dir /usr/share/doc --dir /usr/share/wikiman \
        --dir /etc --dir /etc/xdg --dir /etc/xdg/wikiman \
        --ro-bind ${pkgs.wikiman}/share/wikiman            /usr/share/wikiman \
        --ro-bind ${arch}/share/doc/arch-wiki         /usr/share/doc/arch-wiki \
        --ro-bind ${tldr}/share/doc/tldr-pages        /usr/share/doc/tldr-pages \
        --ro-bind ${gentoo}/share/doc/gentoo-wiki     /usr/share/doc/gentoo-wiki \
        --ro-bind ${freebsd}/share/doc/freebsd-docs   /usr/share/doc/freebsd-docs \
        --ro-bind ${wikimanConf}                       /etc/xdg/wikiman/wikiman.conf \
        --setenv PATH "$PATH" \
        --setenv LANG "$LANG" \
        --setenv LC_ALL "$LC_ALL" \
        --setenv LOCALE_ARCHIVE "$LOCALE_ARCHIVE" \
        --setenv PARALLEL "$PARALLEL" \
        --setenv TMPDIR "$TMPDIR" \
        --setenv TEMP "$TEMP" \
        --setenv TMP "$TMP" \
        -- ${inner} "$@"
    '';
  }
