# API: import ./music-domain.nix { inherit pkgs; } returns a buildable check.
# Runs the same reconciler used by qbittorrent.preStart against real INI bytes.
{pkgs}:
pkgs.runCommand "music-domain" {
  nativeBuildInputs = [pkgs.python3];
} ''
  python - <<'PY'
  from pathlib import Path
  import stat
  import subprocess
  import sys

  reconciler = "${../../system/services/music/reconcile-qbittorrent-domain.py}"
  key = b"WebUI\\ServerDomains="
  credentials = (
      b"WebUI\\Username=custom-admin\n"
      b"WebUI\\Password_PBKDF2=\"@ByteArray(generated:salted:hash==)\"\n"
  )
  unrelated = (
      b"[BitTorrent]\n"
      b"Session\\DefaultSavePath=/srv/media/custom-downloads/\n"
      b"Session\\GlobalMaxRatio=3.5\n"
      b"\n[Other]\n"
      b"WebUI\\ServerDomains=do-not-change.example.test\n"
      b"Unrelated=keep=this;value\n"
  )
  preferences = (
      b"[Preferences]\n"
      + credentials
      + b"WebUI\\LocalHostAuth=false\n"
      + b"WebUI\\Port=9999\n"
  )
  existing = preferences + key + b"old.example.test\n\n" + unrelated
  absent = preferences + b"\n" + unrelated

  for name, fixture, mode in [
      ("existing", existing, 0o600),
      ("absent", absent.replace(b"\n", b"\r\n"), 0o640),
  ]:
      directory = Path(name)
      directory.mkdir()
      profile = directory / "qBittorrent.conf"
      profile.write_bytes(fixture)
      profile.chmod(mode)
      initial_metadata = profile.stat()
      newline = b"\r\n" if name == "absent" else b"\n"

      for domain in ["music.example.test", "renamed-music.example.test"]:
          subprocess.run([sys.executable, reconciler, str(profile), domain], check=True)
          entry = key + domain.encode() + newline
          if name == "existing":
              expected = fixture.replace(key + b"old.example.test\n", entry)
          else:
              expected = fixture.replace(b"[Preferences]" + newline, b"[Preferences]" + newline + entry)

          actual = profile.read_bytes()
          # Byte equality checks every credential, mutable setting, comment and
          # other section, including the same key outside Preferences.
          assert actual == expected, (name, domain, actual)
          assert credentials.replace(b"\n", newline) in actual
          assert unrelated.replace(b"\n", newline) in actual
          metadata = profile.stat()
          assert stat.S_IMODE(metadata.st_mode) == mode
          assert (metadata.st_uid, metadata.st_gid) == (initial_metadata.st_uid, initial_metadata.st_gid)
          assert list(directory.iterdir()) == [profile], "temporary profile leaked"

          subprocess.run([sys.executable, reconciler, str(profile), domain], check=True)
          repeated = profile.stat()
          assert profile.read_bytes() == expected
          assert (repeated.st_ino, repeated.st_mtime_ns) == (metadata.st_ino, metadata.st_mtime_ns), "unchanged profile rewritten"

  PY
  touch "$out"
''
