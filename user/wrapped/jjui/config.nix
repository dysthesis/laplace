_: {
  suggest.exec.mode = "fuzzy";
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
