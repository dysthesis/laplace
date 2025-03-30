{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    difftastic
  ];
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
      commit = {
        gpgsign = true;
        verbose = true;
      };
      tag.sort = "version:refname";
      branch = {
        autosetupmerge = "true";
        sort = "-committerdate";
      };
      merge.conflictstyle = "zdiff3";
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      help.autocorrect = "prompt";
      column.ui = "auto";
      diff = {
        # external = "difft";
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      pull.ff = "only";
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      core.excludesfile = "~/.gitignore";
    };
  };
}
