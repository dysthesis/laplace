{
  pkgs,
  cacheDir ? "$HOME/.cache/dwl_info",
  ...
}: let
  inherit (pkgs) writeText;
in
  writeText "config.yml"
  /*
  yaml
  */
  ''
    highlight: &highlight fabd2fff
    textcolor: &textcolor d0d0d0ff
    focus: &focus 831c1cff
    foreground-highlight: &foreground-highlight 000000ff
    grey: &grey 080808ff
    lightred: &lightred ffaa88ff
    brightred: &brightred d70000ff
    std_underline: &std_underline {underline: { size: 2, color: *brightred}}
    white: &white ffffffff
    black: &black 000000ff
    orange: &orange ffa600ff
    bar:
      height: 30
      location: bottom
      background: *black
      foreground: *white

      left:
        - dwl:
          number-of-tags: 9
    	    dwl-info-filename: "${cacheDir}"
          name-of-tags: [ 1, 2, 3, 4, 5, 6, 7, 8, 9 ]
          content:
            list:
              items:
                - map:
                    conditions:
                      # default tag
                      id == 0: {string: {text: " {layout} {title} ", foreground: *white}}

                      selected: {string: {text: " {name} ", foreground: *white}} #, font: Symbols Nerd Font:pixelsize=35}}
                      ~empty: {string: {text: " {name} ", foreground: *grey}}
                      urgent: {string: {text: " {name} ", foreground: *highlight}}
      right:
        - clock:
            content:
              - string: {text: , font: "Font Awesome 6 Free:style=solid:size=12"}
              - string: {text: "{date}", right-margin: 5}
              - string: {text: , font: "Font Awesome 6 Free:style=solid:size=12"}
              - string: {text: "{time}"}
  ''
