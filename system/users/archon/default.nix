{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf elem;
  inherit (builtins) filter hasAttr;
  cfg = elem "archon" config.laplace.users;
  # Only attach to groups that some other module actually defines, so the user
  # composes cleanly regardless of which services a given guest enables.
  ifExists = groups: filter (group: hasAttr group config.users.groups) groups;
in {
  config = mkIf cfg {
    users.users.archon = {
      description = "Archon";
      isNormalUser = true;
      hashedPassword = "$y$j9T$CHw.uVYenh9K/w.r7JYrW.$OFud2Bjlrhk1FWJZWjkOIJ9RREUBJ8Dg/8UFa1Ns8n5";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoKu8wF8Ts5xlCcKBQ8zRU7A4NsujnhzfsGfaP62kf2 demiurge@phobos"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDUPaVrhCJ8fDKDYCcIeICgCv6W+0GdGmMDrngIg1oKg demiurge@deimos"
      ];
      extraGroups =
        [
          "wheel"
          "video"
          "audio"
          "input"
          "nix"
          "networkmanager"
        ]
        ++ ifExists [
          "network"
          "docker"
          "podman"
          "libvirt"
          "render"
          "ollama"
        ];
    };
  };
}
