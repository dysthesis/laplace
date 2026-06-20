# Bound switch-to-configuration so a hung activation cannot spin forever.
#
# switch-to-configuration-ng's systemd job-wait loops (`block_on_jobs` and the
# `nixos-activation.service` wait in src/main.rs) have no timeout - unlike the
# adjacent daemon-reload/re-exec loops, which bail after 180s. When the systemd
# dbus transport drops mid-switch (a systemd re-exec on a systemd bump, a
# dbus-broker reload, or a stopped unit closing fds - nixpkgs #353450, #429068,
# #462179) `conn.process()` starts erroring, the loop discards it
# (`_ = conn.process(...)`), and STC busy-loops at 100% CPU forever holding
# /run/nixos/switch-to-configuration.lock. Every later deploy then dies with
# "Could not acquire lock", and on a socket-activated-sshd guest the half-switch
# can strand the host entirely. Upstream treats the unbounded wait as intentional
# and will not add a timeout (they blame the offending unit), so we bound it
# externally: wrap the binary in `timeout` so a hang self-terminates, releases
# the flock, and fails the deploy cleanly (retryable) instead of hanging.
#
# simplification: a blunt outer `timeout` also caps legitimate switches. 20m is
# far above the seconds these configs take, but a genuinely slow service start
# could in theory be killed - raise the bound if a real activation needs longer.
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
