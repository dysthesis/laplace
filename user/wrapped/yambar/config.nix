{ pkgs, ... }:
let
  inherit (pkgs) writeText;
in
writeText "config.yml"
  # yaml
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

    bg_default: &bg_default
      stack:
        - background: {color: 81A1C1ff}
        - underline: {size: 4, color: D8DEE9ff}

    bar:
      height: 30
      location: bottom
      background: *black
      foreground: *white

      left:
        - river:
            anchors:
              - base: &river_base
                  left-margin: 10
                  right-margin: 13
                  default: {string: {text: , font: *font}}
                  conditions:
                    id == 1: {string: {text: 1, font: *font}}
                    id == 2: {string: {text: 2, font: *font}}
                    id == 3: {string: {text: 3, font: *font}}
                    id == 4: {string: {text: 4, font: *font}}
                    id == 5: {string: {text: 5, font: *font}}
            content:
              map:
                on-click:
                  left: sh -c "riverctl set-focused-tags $((1 << ({id} - 1)))"
                  right: sh -c "riverctl toggle-focused-tags $((1 << ({id} -1)))"
                  middle: sh -c "riverctl toggle-view-tags $((1 << ({id} -1)))"
                conditions:
                  state == urgent:
                    map:
                      <<: *river_base
                      deco: {background: {color: D08770ff}}
                  state == focused:
                    map:
                      <<: *river_base
                      deco: *bg_default
                  state == visible && ~occupied:
                    map:
                      <<: *river_base
                  state == visible && occupied:
                    map:
                      <<: *river_base
                      deco: *bg_default
                  state == unfocused:
                    map:
                      <<: *river_base
                  state == invisible && ~occupied: {empty: {}}
                  state == invisible && occupied:
                    map:
                      <<: *river_base
                      deco: {underline: {size: 3, color: ea6962ff}}

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
                            default: {string: {text: , font: *font, foreground: *grey}}
                            conditions:
                              state == down: {string: {text: "No signal", font: *font, foreground: *grey}}
                              state == up:
                                map:
                                  default:
                                    - string: {text: , font: *font}
                                    - string: {text: " {ssid}", font: *font}
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
                    - string: {text: " {capacity}% {estimate}", font: *font}
            content:
              map:
                conditions:
                  state == unknown:
                    <<: *discharging
                  state == discharging:
                    <<: *discharging
                  state == charging:
                    - string: {text: , foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}% {estimate}", font: *font}
                  state == full:
                    - string: {text: , foreground: *brightgreen, font: *font}
                    - string: {text: " {capacity}%", font: *font}
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
                    - string: {text: " {capacity}%", font: *font}

        - clock:
            time-format: "%H:%M"
            date-format: "%d.%m.%Y"
            content:
              - string: {text: " {date}", right-margin: 7, font: *font}
              - string: {text: " {time}", font: *font}
  ''
