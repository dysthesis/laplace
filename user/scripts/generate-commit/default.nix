{
  pkgs,
  curl,
  git,
  jq,
  jujutsu,
  gnused,
  fzf,
  ...
}: let
  inherit
    (pkgs)
    symlinkJoin
    runCommandLocal
    ;
  deps = [
    curl
    git
    jq
    jujutsu
    gnused
    fzf
  ];
  name = "generate-commit";
  script = runCommandLocal "script" {} ''
    mkdir -pv $out/bin
    install -m755 ${./generate-commit.sh} $out/bin/${name}
    patchShebangs $out/bin/${name}
  '';
in
  symlinkJoin rec {
    inherit name;
    paths = [script] ++ deps;
    buildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/${name} --prefix PATH : $out/bin";
    meta.mainProgram = name;
  }
