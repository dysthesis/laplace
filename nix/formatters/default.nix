_: {
  projectRootFile = "flake.nix";
  # sops-encrypted secrets must never be reformatted: prettier re-indents the
  # YAML and rewraps the base64 AGE blocks, churning every secret file with a
  # huge diff even though the ciphertext is unchanged. Exclude the dir from all
  # formatters.
  settings.global.excludes = [
    "system/secrets/*"
    # Vendored shader DSL includes non-JSON files with .json extensions.
    "system/services/minecraft/retirement-home-packwiz/**"
  ];
  programs = {
    alejandra.enable = true;
    deadnix.enable = true;
    prettier.enable = true;
    toml-sort.enable = true;
    shfmt = {
      enable = true;
      indent_size = 4;
    };
  };
}
