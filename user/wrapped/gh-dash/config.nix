_: {
  confirmQuit = false;
  defaults = {
    issuesLimit = 20;
    layout = {
      issues = {
        assignees = {hidden = true;};
      };
      prs = {
        assignees = {hidden = true;};
        base = {hidden = true;};
      };
    };
    notificationsLimit = 20;
    preview = {
      open = true;
      width = 0.45;
    };
    prsLimit = 20;
    refetchIntervalMinutes = 5;
    view = "prs";
  };
  includeReadNotifications = false;
  issuesSections = [
    {
      filters = "is:open author:@me";
      title = "My Issues";
    }
    {
      filters = "is:open assignee:@me";
      title = "Assigned";
    }
    {
      filters = "is:open involves:@me -author:@me";
      title = "Involved";
    }
    {
      filters = "is:open label:priority sort:updated-desc";
      title = "Priority";
    }
    {
      filters = "is:open no:label sort:updated-desc";
      title = "Unlabelled";
    }
  ];
  keybindings = {
    notifications = [
      {
        builtin = "markAsDone";
        key = "d";
      }
      {
        builtin = "markAllAsDone";
        key = "D";
      }
    ];
    prs = [
      {
        builtin = "checkout";
        key = "O";
      }
    ];
    universal = [
      {
        command = "cd {{.RepoPath}} && lazygit";
        key = "g";
        name = "lazygit";
      }
    ];
  };
  notificationsSections = [
    {
      filters = "is:unread";
      title = "Unread";
    }
    {
      filters = "reason:review-requested";
      title = "Review";
    }
    {
      filters = "reason:mention";
      title = "Mentioned";
    }
    {
      filters = "reason:participating";
      title = "Participating";
    }
    {
      filters = "reason:assign";
      title = "Assigned";
    }
  ];
  pager = {diff = "less";};
  prSections = [
    {
      filters = "is:open author:@me sort:updated-desc";
      title = "My PRs";
    }
    {
      filters = "is:open review-requested:@me -author:@me sort:updated-desc";
      title = "Review";
    }
    {
      filters = "is:open involves:@me -author:@me sort:updated-desc";
      title = "Involved";
    }
    {
      filters = "is:open updated:>={{ nowModify \"-2w\" }} sort:updated-desc";
      title = "Recent";
    }
    {
      filters = "is:open status:failure sort:updated-desc";
      title = "Failing CI";
    }
  ];
  showAuthorIcons = true;
  smartFilteringAtLaunch = true;
}
