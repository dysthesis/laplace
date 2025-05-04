{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  inherit
    (pkgs)
    system
    ;

  inherit
    (lib)
    mkIf
    ;
  inherit
    (builtins)
    elem
    filter
    hasAttr
    ;

  cfg = elem "demiurge" config.laplace.users;
  ifTheyExist = groups: filter (group: hasAttr group config.users.groups) groups;
in {
  config = mkIf cfg {
    users.users.demiurge = {
      description = "Demiurge";
      shell = "${pkgs.configured.bash}/bin/bash";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF4Rfg1TJZb861LSAJZn1xKNO1PXf7Oz2Mucq//9Dr9s demiurge@phobos"
      ];
      hashedPassword = "$y$j9T$WtVEPLB064z6W2eWFUPK81$xT7V9MzUIS.gcoaJzfYjMRY/I5Zi5Hl57XDo9EMwll5";
      extraGroups =
        [
          "wheel"
          "video"
          "audio"
          "input"
          "nix"
          "networkmanager"
        ]
        ++ ifTheyExist [
          "network"
          "docker"
          "podman"
          "libvirt"
        ];
      packages = with pkgs;
        [
          inputs.babel.packages.${system}.fzf-bibtex
          unstable.zotero
          swaylock
          signal-desktop
          git
          direnv
          brightnessctl
          wl-clipboard
          gnupg
          atuin
          unstable.sbctl
          protonvpn-gui
          networkmanagerapplet
          tor-browser-bundle-bin
          (pkgs.uutils-coreutils.override {prefix = "";})
          inputs.poincare.packages.${system}.default
          (inputs.daedalus.packages.${system}.default.override {
            shell = "${pkgs.configured.fish}/bin/fish";
          })
          grim
          slurp
          swappy
          bat
          obsidian
          (pkgs.writeShellScriptBin "bibfzf" ''
            # Adjust the command below to extract the citation keys or titles from your .bib file.
            # For example, assume each entry starts with an '@' and the key is within braces.
            selected=$(grep -h '^@' ~/path/to/library.bib | sed 's/@.*{//' | sed 's/,.*//' | fzf --prompt="Select a citation: ")

            if [ -n "$selected" ]; then
              # Display the full BibTeX entry for the selected citation.
              awk -v key="$selected" '
                BEGIN {found=0}
                $0 ~ "@" {found=0}
                $0 ~ key {found=1}
                found {print}
              ' $argv
            fi
          '')
        ]
        ++ (with pkgs.configured; [
          btop
          hyprland
          newsraft
          bemenu
          yambar
          fish
          bash
          ytfzf
          zathura
          ani-cli
          spotify-player
          zen
          vesktop
          taskwarrior
          taskwarrior-tui
          weechat
          mpv
          timewarrior
          ghostty
        ]);
    };
  };
}
