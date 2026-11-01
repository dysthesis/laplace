{
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mapAttrsToList;
  inherit (lib.strings) concatStringsSep;
  inherit (lib.laplace.pkgs) mkWrapper;
  inherit
    (pkgs)
    anime4k
    writeText
    ;

  low1k = import ./low1k.nix {inherit anime4k;};
  low1kParsed =
    low1k |> mapAttrsToList (k: v: "${k} ${v}") |> concatStringsSep "\n" |> writeText "inputs.conf";

  # Use Whisper only in the background decoder. Do not change playback's FFmpeg.
  transcriptionFFmpeg =
    (pkgs.ffmpeg-full.override {
      whisper-cpp = (pkgs.whisper-cpp.override {vulkanSupport = true;}).overrideAttrs (old: {
        patches = (old.patches or []) ++ [./whisper-compute-queue.patch];
      });
    }).overrideAttrs (old: {
      # The upstream filter has no whisper_full_params.initial_prompt option.
      patches = (old.patches or []) ++ [./whisper-prompt.patch];
    });
  transcriber = pkgs.mpv-unwrapped.override {ffmpeg = transcriptionFFmpeg;};
  whisperModel = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };

  mpv = pkgs.mpv.override {
    scripts = builtins.attrValues {
      inherit
        (pkgs.mpvScripts)
        sponsorblock
        thumbfast
        mpv-webm
        mpris
        uosc
        ;
    };
  };
  config = pkgs.stdenv.mkDerivation (_finalAttrs: {
    pname = "mpv-config";
    version = "0.0.1";

    src = ./config;
    buildPhase = ''
      mkdir -p $out/
      cp -r $src/* $out/
      cp ${low1kParsed} $out/input.conf
      substituteInPlace $out/scripts/auto-subs.lua \
        --replace-fail '@transcriber@' '${lib.getExe transcriber}' \
        --replace-fail '@model@' '${whisperModel}' \
        --replace-fail '@mktemp@' '${pkgs.coreutils}/bin/mktemp'
    '';
  });
in
  mkWrapper pkgs mpv {
    addFlags = ["--config-dir=${config}"];
    binPath = [
      pkgs.ffmpeg
      pkgs.yt-dlp
    ];
  }
