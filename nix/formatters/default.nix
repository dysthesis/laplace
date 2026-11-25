_: {
  projectRootFile = "flake.nix";
  # Formatters can change encrypted SOPS data.
  settings.global.excludes = [
    ".claude/**"
    ".serena/**"
    ".tokensave/**"
    "AGENTS.md"
    "system/secrets/*"
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
