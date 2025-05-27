{todo-txt-cli, ...}:
todo-txt-cli.overrideAttrs (old: {
  installPhase =
    /*
    sh
    */
    builtins.trace "${./todo.cfg}"
    ''
      ${old.installPhase or ""}
      cp ${./todo.cfg} $out/bin/todo.cfg
    '';
})
