{
  config,
  lib,
  ...
}: let
  inherit (lib) mkIf elem;
  inherit (builtins) filter hasAttr;
  cfg = elem "archon" config.laplace.users;
  keys = import ../keys.nix;
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
        keys.phobos
        keys.deimos
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
