{lib}: {
  domain = lib.mkOption {
    type = lib.types.str;
    example = "zotero.example.com";
    description = "Public hostname used for browser and Zotero client URLs.";
  };
  port = lib.mkOption {
    type = lib.types.port;
    default = 8000;
    description = "Loopback port exposed to the host reverse proxy.";
  };
  dataDir = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/altero";
    description = "Persistent directory containing the SQLite database and attachments.";
  };
  image = lib.mkOption {
    type = lib.types.str;
    default = "ghcr.io/eseifert/altero:1.0.0-alpha.2@sha256:0e21bcb764f155330e74f6d8dfae79b40ba352a044ee1eb073b5c73fb39cde8d";
    description = "Pinned Altero OCI image.";
  };
}
