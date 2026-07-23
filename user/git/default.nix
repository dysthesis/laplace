{
  config,
  lib,
  pkgs,
  ...
}: let
  # Single source of truth: the GPG key used for both commit signing and the
  # gitattributes `encrypt` filter below. (Previously `${config.user.signingKey}`,
  # which referenced a `config` arg this module doesn't take -> eval error.)
  signingKey = "6008B52F296392B0";
in
  # Workstation-only (demiurge hosts). This module writes /etc/gitconfig, which
  # EVERY git on the host reads — including Forgejo's server-side git on
  # hephaestus, where `commit.gpgsign` (no secret key in the service's keyring)
  # 500'd PR merges and `diff.external = difft` (not on the service PATH) 500'd
  # PR diff views. Headless guests must not inherit a human's git identity.
  lib.mkIf (lib.elem "demiurge" config.laplace.users) {
    environment.systemPackages = with pkgs; [
      cloudflared
      difftastic
    ];
    programs.git = {
      enable = true;
      lfs.enable = true;
      # Build git with the libsecret credential helper so HTTPS tokens (e.g. the
      # Forgejo PAT for git.dysthesis.com) live in the desktop keyring, not plaintext.
      # The override ships git-credential-libsecret in $out/bin, so `helper = libsecret`
      # (set in config below) resolves on PATH. Needs a running Secret Service
      # (gnome-keyring / KWallet / KeePassXC), else the helper no-ops and git prompts.
      package = pkgs.git.override {withLibsecret = true;};
      config = {
        init.defaultBranch = "main";
        user = {
          email = "antheoraviel@protonmail.com";
          name = "Dysthesis";
          inherit signingKey;
        };
        github.user = "dysthesis";
        gitlab."nw-syd-gitlab.cseunsw.tech/api/v4".user = "z5437039";
        filter.encrypt = {
          clean = "gpg --batch --yes --encrypt --recipient ${signingKey}";
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
