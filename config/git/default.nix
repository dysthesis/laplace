{
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        email = "antheoraviel@protonmail.com";
        name = "Dysthesis";
        signingKey = "4F41D2DFD42D5568";
      };
      signing.signByDefault = true;
      branch.autosetupmerge = "true";
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      diff.external = "difft";
      pull.ff = "only";
      rebase = {
        autoSquash = true;
        autoStash = true;
      };
    };
  };
}
