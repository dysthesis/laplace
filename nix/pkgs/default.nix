final: prev: {
  fast-fonts = final.callPackage ./fast-fonts {};
  sf-pro = final.callPackage ./sf-pro {};
  georgia-fonts = final.callPackage ./georgia-fonts {};
  jbcustom-nf = final.callPackage ./jbcustom-nf {};
  literata = final.callPackage ./literata {};
  soularr = final.callPackage ./soularr {};

  # Karakeep 0.32 requires its pinned better-sqlite3 11.3; drop when it supports Node 24.
  karakeep = prev.karakeep.override {nodejs = final.nodejs_22;};

  # Curried: `pkgs.proxmox-vma { rawImage; qemuConf; baseName; }`. Consumed by
  # the proxmox guest profile to turn a disko raw image into a VMA archive.
  proxmox-vma = final.callPackage ./proxmox-vma {};
}
