{
  pkgs,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  ghostty,
  bemenu,
  ...
}: let
  inherit
    (pkgs)
    symlinkJoin
    runCommandLocal
    ;
  deps = [
    gawk
    zk
    uutils-coreutils-noprefix
    ghostty
    bemenu
  ];
  name = "bemenu-zk";
  script = runCommandLocal "script" {} ''
    mkdir -pv $out/bin
    cp ${./script.sh} $out/bin/${name}
    chmod +x  $out/bin/${name}
  '';
in
  symlinkJoin rec {
    inherit name;
    paths = [script] ++ deps;
    buildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
    meta.mainProgram = name;
  }
