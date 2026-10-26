{
  config,
  lib,
  ...
}: {
  imports = [./config.nix];

  options.laplace.services.immich =
    {
      enable = lib.mkEnableOption "Immich self-hosted photo and video backup";
      postgresqlPersistenceRoot = lib.mkOption {
        type = lib.types.path;
        default = config.services.postgresql.dataDir;
        description = "Provider persistence boundary; the recipe avoids a nested mount when sharing local PostgreSQL.";
      };
    }
    // import ./settings.nix {inherit lib;};
}
