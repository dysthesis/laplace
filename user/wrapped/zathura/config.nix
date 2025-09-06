lib: let
  inherit
    (lib)
    isBool
    concatStringsSep
    mapAttrsToList
    ;

  opacity = "1";

  options = {
    recolor = true;
    adjust-open = "width";
    pages-per-row = 1;
    scroll-page-aware = true;
    smooth-scroll = true;
    smooth-zoom = true;
    selection-clipboard = "clipboard";
    guioptions = "sv";
    zoom-min = 10;
    render-loading = false;
    scroll-full-overlap = "0.01";
    scroll-step = 100;
    default-bg = "rgba(0,0,0,${opacity})";
    default-fg = "#ffffff";
    recolor-darkcolor = "#ffffff";
    recolor-lightcolor = "rgba(0,0,0,${opacity})";
  };

  formatLine = n: v: let
    formatValue = v:
      if isBool v
      then
        (
          if v
          then "true"
          else "false"
        )
      else toString v;
  in ''set ${n}	"${formatValue v}"'';
  formattedOptions =
    options
    |> mapAttrsToList formatLine
    |> concatStringsSep "\n";
in ''
  ${formattedOptions}
  map j feedkeys "<C-Down>"
  map k feedkeys "<C-Up>"
''
