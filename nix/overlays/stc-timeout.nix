# switch-to-configuration can keep its lock after a D-Bus failure.
# shortcut: The timeout can stop a slow activation. Increase it if activations run for more than 20 minutes.
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
