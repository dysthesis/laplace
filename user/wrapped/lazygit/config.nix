{
  lib,
  generate-commit,
  ...
}: {
  customCommands = [
    {
      key = "A";
      context = "files";
      description = "AI commit";
      prompts = [
        {
          type = "menuFromCommand";
          title = "Select AI commit message";
          key = "msg";
          command = "${lib.getExe generate-commit}";
        }
      ];
      command = "git commit -m '{{.Form.msg}}'";
    }
  ];
}
