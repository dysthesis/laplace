final: prev: {
  fast-fonts = final.callPackage ./fast-fonts {};
  sf-pro = final.callPackage ./sf-pro {};
  georgia-fonts = final.callPackage ./georgia-fonts {};
  jbcustom-nf = final.callPackage ./jbcustom-nf {};
  literata = final.callPackage ./literata {};
  soularr = final.callPackage ./soularr {};

  # Karakeep 0.32 must use better-sqlite3 11.3. Remove this override when Karakeep supports Node 24.
  karakeep = prev.karakeep.override {nodejs = final.nodejs_22;};

  proxmox-vma = final.callPackage ./proxmox-vma {};
}
