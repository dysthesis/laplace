{lib, ...}: let
  inherit (lib) fold;
  browser = ["firefox.desktop"];
  useBrowser =
    fold (
      curr: acc:
        acc
        // {${curr} = browser;}
    )
    {}
    [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
      "x-scheme-handler/ftp"
      "x-scheme-handler/about"
      "x-scheme-handler/unknown"
      "application/x-extension-htm"
      "application/x-extension-html"
      "application/x-extension-shtml"
      "application/xhtml+xml"
      "application/x-extension-xhtml"
      "application/x-extension-xht"
    ];

  useZathura =
    fold (curr: acc:
      acc
      // {
        ${curr} = ["org.pwmt.zathura.desktop"];
      })
    {}
    [
      "application/pdf"
      "application/epub+zip"
    ];

  associations = useBrowser // useZathura;
in {
  xdg.mimeApps = {
    enable = true;
    associations.added = associations;
    defaultApplications = associations;
  };
}
