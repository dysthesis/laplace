{
  pkgs,
  gawk,
  uutils-coreutils-noprefix,
  gnused,
  fzf,
  ...
}:
let
  inherit (pkgs)
    symlinkJoin
    runCommandLocal
    ;
  deps = [
    gawk
    uutils-coreutils-noprefix
    gnused
    fzf
  ];
  name = "generate-commit";
  script = runCommandLocal "script" { } ''
    mkdir -pv $out/bin
    cp ${./generate-commit.sh} $out/bin/${name}
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
