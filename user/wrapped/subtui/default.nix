{
  lib,
  pkgs,
  buildGoModule,
  versionCheckHook,
}: let
  sources = import ../npins;
  src = sources.subtui;
in
  buildGoModule (finalAttrs: rec {
    pname = "subtui";
    inherit src;
    inherit (src) version;

    vendorHash = "sha256-ZI6K3EupgqPvE1ixd7VpJ9cvND0rwcrvRcPfbdjjK+U=";

    nativeBuildInputs = [pkgs.makeWrapper];

    ldflags = [
      "-s"
      "-w"
      "-X main.version=v${finalAttrs.version}"
      "-X main.commit=${finalAttrs.src.revision}"
    ];

    postInstall = ''
      mv $out/bin/SubTUI $out/bin/subtui
    '';

    postFixup = ''
      wrapProgram $out/bin/subtui \
        --prefix PATH : ${lib.makeBinPath [pkgs.mpv-unwrapped]}
    '';

    nativeInstallCheckInputs = [versionCheckHook];
    versionCheckProgramArg = "-v";
    doInstallCheck = true;

    meta = {
      description = "Lightweight Subsonic TUI music player with scrobbling support";
      homepage = "https://github.com/MattiaPun/SubTUI";
      license = lib.licenses.mit;
      mainProgram = "subtui";
    };
  })
