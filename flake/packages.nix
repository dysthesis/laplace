{
  perSystem = {pkgs, ...}: {
    packages = {
      inherit (pkgs) sf-pro generate-domains-blocklist;
    };
  };
}
