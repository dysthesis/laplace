_: {
  suggest.exec.mode = "fuzzy";
  revisions.template = "builtin_log_compact";
  custom_commands = {
    tug = {
      key = ["T"];
      args = [
        "bookmark"
        "move"
        "--from"
        "closest_bookmark($change_id)"
        "--to"
        "closest_pushable($change_id)"
      ];
    };
  };
}
