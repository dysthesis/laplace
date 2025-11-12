{
  pkgs,
  gawk,
  zk,
  uutils-coreutils-noprefix,
  ghostty,
  gnused,
  neovim,
  ...
}:
let
  inherit (pkgs)
    symlinkJoin
    runCommandLocal
    ;
  deps = [
    gawk
    zk
    uutils-coreutils-noprefix
    gnused
    ghostty
    neovim
  ];
  name = "zk-capture";
  script = runCommandLocal "script" { } ''
    mkdir -pv $out/bin
    cp ${./script.sh} $out/bin/${name}
    patchShebangs $out/bin/${name}
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
