{
  lib,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    cloudflared
    difftastic
  ];
  # Build git with the libsecret credential helper so HTTPS tokens (e.g. the
  # Forgejo PAT for git.dysthesis.com) live in the desktop keyring, not plaintext.
  # The override ships git-credential-libsecret in $out/bin, so `helper = libsecret`
  # resolves on PATH. Needs a running Secret Service (gnome-keyring / KWallet /
  # KeePassXC) on the session, or the helper no-ops and git falls back to prompting.
  programs.git.package = pkgs.git.override {withLibsecret = true;};
  programs.ssh.extraConfig = ''
    Host git.dysthesis.com
      User git
      ProxyCommand ${lib.getExe pkgs.cloudflared} access ssh --hostname ssh.git.dysthesis.com
  '';
  programs.git = rec {
    enable = true;
    lfs.enable = true;
    config = {
      init.defaultBranch = "main";
      user = {
        email = "antheoraviel@protonmail.com";
        name = "Dysthesis";
        signingKey = "6008B52F296392B0";
      };
      github.user = "dysthesis";
      gitlab."nw-syd-gitlab.cseunsw.tech/api/v4".user = "z5437039";
      filter.encrypt = {
        clean = "gpg --batch --yes --encrypt --recipient ${config.user.signingKey}";
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
          driver = "${lib.getExe pkgs.unstable.mergiraf} merge --git %O %A %B -s %S -x %X -y %Y -p %P -l %L";
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
      credential.helper = "libsecret";
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
        logg = "log --graph --abbrev-commit --decorate --format=format:'%C(bold blue)%h%C(reset) - %C(bold cyan)%aD%C(reset) %C(bold green)(%ar)%C(reset)%C(auto)%d%C(reset)%n''          %C(white)%s%C(reset) %C(dim white)- %an%C(reset)'";
      };
      core.excludesfile = "~/.gitignore";
    };
  };
}
