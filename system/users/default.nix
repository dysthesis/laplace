{
  lib,
  config,
  ...
}: {
  imports = [
    (lib.laplace.modules.mkSelector {
      dir = ./.;
      option = ["laplace" "users"];
      description = "Which users to enable";
    })
  ];

  config.users = {
    # Ephemeral roots require declarative user changes.
    mutableUsers = !config.mnemosyne.enable;
    users.root.hashedPassword = "!";
  };
}
