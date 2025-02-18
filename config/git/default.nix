{
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        email = "antheoraviel@protonmail.com";
        name = "Dysthesis";
      };
      branch.autosetupmerge = "true";
      push.default = "current";
      pull.ff = "only";
      rebase = {
        autoSquash = true;
        autoStash = true;
      };
    };
  };
}
