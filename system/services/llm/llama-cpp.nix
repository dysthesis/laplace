{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  inherit (lib) mkIf;

  mkIf' = cond: expr:
    if cond
    then expr
    else {};

  cfg = config.laplace.services.llm;

  models =
    builtins.mapAttrs
    (_key: val: pkgs.fetchurl val)
    cfg.modelRegistry;

  chatModel = models."${cfg.model}";
  embeddingModel = models."${cfg.embedding.model}";

  llamaPackage = let
    inherit (pkgs.unstable) rocmPackages;
    rocmGpuTargets = [
      "gfx908"
      "gfx1030"
      "gfx1100"
    ];
    rocmLibs = with rocmPackages; [
      clr
      hipblas
      rocblas
      rocsolver
      rocsparse
      rocm-device-libs
      rocm-smi
    ];
    rocmPath = pkgs.buildEnv {
      name = "rocm-path";
      paths = rocmLibs;
    };
  in
    (pkgs.unstable.llama-cpp.override {
      rocmSupport = true;
      inherit rocmGpuTargets;
    }).overrideAttrs (old:
      {
        env =
          (old.env or {})
          // {
            HSA_OVERRIDE_GFX_VERSION = "10.3.0";
            ROCM_PATH = "${rocmPath}";
          };
        buildInputs = old.buildInputs ++ [rocmPackages.llvm.openmp pkgs.zstd];
        dontStrip = true;
        cmakeFlags =
          (lib.filter (
              p:
                !(lib.strings.hasSuffix "hipcc" p)
                && !(lib.strings.hasPrefix "-DLLAMA_BUILD_NUMBER" p)
            )
            old.cmakeFlags)
          ++ [
            "-DLLAMA_BUILD_NUMBER:STRING=${
              if cfg.turboquant.enable
              then "0"
              else old.version
            }"
            "-DGGML_HIPBLAS=1"
            "-DGGML_CUDA_FORCE_MMQ=1"
            "-DGGML_NATIVE=1"
            "-DGGML_LTO=1"
          ];
      }
      // mkIf' cfg.turboquant.enable rec {
        pname = "llama-cpp-turboquant";
        version = "4d24ad87b8ed2ad160809af41930f1e04b83f234";
        src = pkgs.unstable.fetchFromGitHub {
          owner = "TheTom";
          repo = "llama-cpp-turboquant";
          rev = version;
          hash = "sha256-sW7AE7YXmKwrtba5UyClZ2+lkE8tUo28QAN12I3lhyU=";
        };
        preConfigure =
          ''
            printf '%s\n' '${version}' > COMMIT
          ''
          + (old.preConfigure or "");
        npmDepsHash = "sha256-RAFtsbBGBjteCt5yXhrmHL39rIDJMCFBETgzId2eRRk=";
      });

  mkLlamaServerService = {
    description,
    model,
    host,
    port,
    extraFlags ? [],
  }: {
    inherit description;
    after = ["network.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "idle";
      KillSignal = "SIGINT";
      ExecStart = "${llamaPackage}/bin/llama-server --log-disable --host ${host} --port ${toString port} -m ${model} ${utils.escapeSystemdExecArgs extraFlags}";
      Restart = "on-failure";
      RestartSec = 300;

      # GPU acceleration needs the device nodes
      PrivateDevices = false;

      DynamicUser = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      NoNewPrivileges = true;
      PrivateMounts = true;
      PrivateTmp = true;
      PrivateUsers = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectSystem = "strict";
      MemoryDenyWriteExecute = true;
      LockPersonality = true;
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      SystemCallErrorNumber = "EPERM";
      ProtectProc = "invisible";
      ProtectHostname = true;
      ProcSubset = "pid";
    };
  };
in {
  config = mkIf (cfg.enable && cfg.backend == "llama-cpp") {
    # Keep all model files pinned in the system closure, so GC cannot drop them.
    system.extraDependencies = builtins.attrValues models;

    services.llama-cpp = {
      enable = true;
      package = llamaPackage;

      model = chatModel;
      inherit (cfg) port host;

      openFirewall = true;
      extraFlags = [
        "--alias"
        "${cfg.model}"
        "--ctx-size"
        (toString cfg.contextSize)
      ];
    };

    systemd.services.llama-cpp-embedding = mkIf cfg.embedding.enable (
      mkLlamaServerService {
        description = "LLaMA C++ embedding server";
        model = embeddingModel;
        inherit (cfg.embedding) host port;
        extraFlags =
          [
            "--alias"
            "${cfg.embedding.model}"
            "--embedding"
            "--ctx-size"
            (toString cfg.embedding.contextSize)
          ]
          ++ cfg.embedding.extraFlags;
      }
    );

    networking.firewall.allowedTCPPorts = lib.optional cfg.embedding.openFirewall cfg.embedding.port;
  };
}
