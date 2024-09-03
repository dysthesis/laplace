{
  perSystem = {pkgs, ...}: {
    packages = {
      inherit (pkgs) sf-pro;
    };
  };
}
