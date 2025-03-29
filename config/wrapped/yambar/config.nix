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
    grey: &grey 2a2a2aff
    lightred: &lightred ffaa88ff
    brightred: &brightred d70000ff
    white: &white ffffffff
    black: &black 000000ff
    orange: &orange ffa600ff
    font: &font "JBMono Nerd Font:style=solid:size=12"
    brightgreen: &brightgreen 789978ff
    bar:
      height: 30
      location: bottom
      background: *black
      foreground: *white

      left:
        - dwl:
            number-of-tags: 9
            dwl-info-filename: "${cacheDir}"
            name-of-tags: [1, 2, 3, 4, 5, 6, 7, 8, 9]
            content:
              list:
                items:
                  - map:
                      conditions:
                        id == 0: {string: {text: " {layout} {title} ", font: *font, foreground: *white}}
                        selected: {string: {text: " {name} ", font: *font, foreground: *white}}
                        ~empty: {string: {text: " {name} ", font: *font, foreground: *grey}}
                        urgent: {string: {text: " {name} ", font: *font, foreground: *highlight}}
      right:
        - pipewire:
           content:
             map:
               conditions:
                 type == sink:
                   map:
                     conditions:
                       muted: {string: {text: "Muted.", font: *font, foreground: *grey}}
                       ~muted: {string: {text: "VOL {cubic_volume}%", foreground: *white, font: *font}}
                     default: {string: {text: "test"}}
        - network:
            content:
              map:
                default: {empty: {}}
                conditions:
                  name == wlp0s20f3:
                    map:
                      conditions:
                        ~carrier: {empty: {}}
                        carrier:
                          map:
                            default: {string: {text: , font: *font, foreground: *grey}} #"suche nach Signal...", foreground: *grey}}
                            conditions:
                              #state == up && ipv4 != "": {string: {text: "verbunden"}} #, right-margin: 5}}
                              #state == up && ipv6 != "": {string: {text: "verbunden"}} #, right-margin: 5}}
                              state == down: {string: {text: "No signal", font: *font, foreground: *grey}}
                              #state == down: {string: {text: , font: *font, foreground: *grey}}
                              state == up:
                                map:
                                  default:
                                    - string: {text: , font: *font}
                                    - string: {text: " {ssid}", font: *font} #{dl-speed:mb}/{ul-speed:mb} Mb/s"}

                                  conditions:
                                    ipv4 == "":
                                      - string: {text: , font: *font, foreground: *grey}
                                      - string: {text: " {ssid}", font: *font, foreground: *grey}
                                    ipv6 == "":
                                      - string: {text: , font: *font, foreground: *white}
                                      - string: {text: " {ssid}", font: *font, foreground: *white}


        - backlight:
            name: amdgpu_bl1
            content: [ string: {text: " ", font: *font}, string: {text: " {percent}% ", font: *font}]

        - battery:
            name: BAT1
            poll-interval: 30000
            anchors:
              discharging: &discharging
                list:
                  items:
                    - ramp:
                        tag: capacity
                        items:
                          - string: {text: " ", foreground: *brightred, font: *font}
                          - string: {text: " ", foreground: *orange, font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", font: *font}
                          - string: {text: " ", foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}% {estimate}", font: *font} #, right-margin: 5}
            content:
              map:
                conditions:
                  state == unknown:
                    <<: *discharging
                  state == discharging:
                    <<: *discharging
                  state == charging:
                    - string: {text: , foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}% {estimate}", font: *font} #, right-margin: 5}
                  state == full:
                    - string: {text: , foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}%", font: *font} #, right-margin: 5}
                  state == "not charging":
                    - ramp:
                        tag: capacity
                        items:
                          - string: {text:  , foreground: *brightred, font: *font}
                          - string: {text:  , foreground: *orange, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                          - string: {text:  , foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}%", font: *font} #, right-margin: 5}

                #    - script:
                #        path: ~/docs/scripts/yams-kbd.sh
                #        args: []
                #        content: {string: {text: "{kbd}"}}
        - clock:
            time-format: "%H:%M"
            date-format: "%d.%m.%Y"
            content:
              - string: {text: " {date}", right-margin: 7, font: *font}
              - string: {text: " {time}", font: *font}
  ''
