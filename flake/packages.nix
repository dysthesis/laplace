{
  perSystem = {pkgs, ...}: {
    packages = {
      sf-pro = pkgs.callPackage ../packages/sf-pro {};
    };
  };
}
