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
    # User changes must be declarative on ephemeral roots.
    mutableUsers = !config.mnemosyne.enable;
    users.root.hashedPassword = "!";
  };
}
