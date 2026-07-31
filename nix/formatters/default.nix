_: {
  projectRootFile = "flake.nix";
  # Formatting rewrites encrypted SOPS payloads; exclude all secret files.
  settings.global.excludes = [
    ".claude/**"
    ".serena/**"
    ".tokensave/**"
    "AGENTS.md"
    "system/secrets/*"
    # Vendored shader DSL includes non-JSON files with .json extensions.
    "system/services/minecraft/packwiz/**"
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
