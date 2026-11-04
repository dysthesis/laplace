{
  pkgs,
  curl,
  git,
  jq,
  jujutsu,
  gnused,
  fzf,
  ...
}:
pkgs.writeShellApplication {
  name = "generate-commit";
  bashOptions = [];
  runtimeInputs = [
    curl
    git
    jq
    jujutsu
    gnused
    fzf
  ];
  text = builtins.readFile ./generate-commit.sh;
}
