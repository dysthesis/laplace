{
  pkgs,
  bemenu,
  fd,
  gawk,
  ghostty,
  jq,
  pandoc,
  uutils-coreutils-noprefix,
  zk,
  ...
}:
let
  inherit (pkgs)
    symlinkJoin
    runCommandLocal
    ;
  deps = [
    bemenu
    fd
    gawk
    ghostty
    jq
    pandoc
    uutils-coreutils-noprefix
    zk
  ];
  name = "bemenu-bib";
  script = runCommandLocal "script" { } ''
    mkdir -pv $out/bin
    cp ${./script.sh} $out/bin/${name}
    chmod +x  $out/bin/${name}
  '';
in
symlinkJoin rec {
  inherit name;
  paths = [ script ] ++ deps;
  buildInputs = [ pkgs.makeWrapper ];
  postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
  meta.mainProgram = name;
}
