_: {
  programs.git = {
    enable = true;
    userName = "Dysthesis";
    userEmail = "antheoraviel@protonmail.com";
    lfs.enable = true;
    # delta.enable = true;
    difftastic.enable = true;
    signing = {
      key = "4F41D2DFD42D5568";
      signByDefault = true;
    };
    aliases = {
      c = "commit -am";
      st = "status";
      a = "add -A";
    };
  };
}
