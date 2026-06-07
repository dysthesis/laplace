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
    # Impermanence means state will not be preserved. Letting users be mutable
    # means that any changes would not be saved. It would be better to enforce
    # that changes to a user must be done declaratively, through this
    # configuration, rather than imperatively.
    mutableUsers = !config.mnemosyne.enable;
    users.root.hashedPassword = "!";
  };
}
