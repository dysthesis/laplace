# switch-to-configuration can spin forever after D-Bus drops, holding its lock.
# An outer timeout fails the deploy and releases the lock.
# simplification: the 20-minute cap can kill a valid slow activation; raise if measured.
final: prev: {
  switch-to-configuration-ng = prev.switch-to-configuration-ng.overrideAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        if [ ! -e "$out/bin/.switch-to-configuration-unbounded" ]; then
          mv "$out/bin/switch-to-configuration" "$out/bin/.switch-to-configuration-unbounded"
        fi
        printf '%s\n' \
          '#!${final.runtimeShell}' \
          'exec ${final.coreutils}/bin/timeout --kill-after=30s 20m "'"$out"'/bin/.switch-to-configuration-unbounded" "$@"' \
          > "$out/bin/switch-to-configuration"
        chmod +x "$out/bin/switch-to-configuration"
      '';
  });
}
