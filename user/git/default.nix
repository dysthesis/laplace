{ lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [ difftastic ];
  programs.git = rec {
    enable = true;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        email = "antheoraviel@protonmail.com";
        name = "Dysthesis";
        signingKey = "4F41D2DFD42D5568";
      };
      github.user = "dysthesis";
      filter.encrypt = {
        clean =
          "gpg --batch --yes --encrypt --recipient ${config.user.signingKey}";
        smudge = "gpg --batch --yes --decrypt";
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
      merge = {
        conflictstyle = "zdiff3";
        tool = "nvimdiff";
        mergigraf = {
          name = "mergiraf";
          driver = "${
              lib.getExe pkgs.unstable.mergiraf
            } merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
        };
      };
      mergetool = {
        nvimdiff.layout = "LOCAL,BASE,REMOTE / MERGED";
        prompt = false;
        keepBackup = false;
      };
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
        external = "difft";
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
      alias = {
        logg =
          "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
      };
      core.excludesfile = "~/.gitignore";
    };
  };
}
