{lib, ...}: {
  imports = [
    ./servers
  ];

  options.laplace.display = {
    foot.fontSize = lib.mkOption {
      type = lib.types.oneOf [lib.types.int lib.types.float];
      default = 9.5;
      description = "Foot font size in points.";
    };
    fuzzel.fontSize = lib.mkOption {
      type = lib.types.oneOf [lib.types.int lib.types.float];
      default = 11.5;
      description = "Fuzzel font size in points.";
    };
  };
}
