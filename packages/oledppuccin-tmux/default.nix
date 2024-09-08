{
  tmuxPlugins,
  fetchFromGitHub,
}:
tmuxPlugins.mkTmuxPlugin rec {
  pluginName = "oledppuccin-tmux";
  version = "ddfe52acc3c4d1361b260cd6f31fa8c1b7e23b7f";
  rtpFilePath = "oledppuccin.tmux";
  src = fetchFromGitHub {
    owner = "dysthesis";
    repo = "oledppuccin-tmux";
    rev = version;
    sha256 = "vcVi+sm6DTTrcnutfphc16pPYinuXnRb1+QFMZEFG5M=";
  };
}
