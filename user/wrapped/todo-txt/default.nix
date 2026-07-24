{todo-txt-cli, ...}:
todo-txt-cli.overrideAttrs (old: {
  installPhase = ''
    ${old.installPhase or ""}
    cp ${./todo.cfg} $out/bin/todo.cfg
  '';
})
