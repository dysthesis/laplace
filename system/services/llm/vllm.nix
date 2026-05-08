{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    escapeShellArg
    mapAttrsToList
    mkIf
    mkMerge
    optional
    optionalAttrs
    ;

  cfg = config.laplace.services.llm;
  inherit (cfg) vllm;

  mkFetchedModel = name: model:
    if model.files != {}
    then
      pkgs.runCommand "vllm-model-${name}" {} (
        ''
          mkdir -p "$out"
        ''
        + concatStringsSep "\n" (mapAttrsToList (
            fileName: file: let
              fetchedFile = pkgs.fetchurl {
                inherit (file) url hash;
              };
            in ''
              target="$out/"${escapeShellArg fileName}
              mkdir -p "$(dirname "$target")"
              ln -s ${escapeShellArg fetchedFile} "$target"
            ''
          )
          model.files)
      )
    else
      pkgs.fetchgit {
        name = "vllm-model-${name}";
        inherit
          (model)
          url
          rev
          hash
          fetchLFS
          ;
      };

  fetchedModels = builtins.mapAttrs mkFetchedModel vllm.modelRegistry;
  activeModel =
    if vllm.modelSource != null
    then fetchedModels.${vllm.modelSource}
    else vllm.model;

  serveArgs =
    [
      "serve"
      (toString activeModel)
      "--host"
      vllm.host
      "--port"
      (toString vllm.port)
      "--served-model-name"
      vllm.servedModelName
      "--max-model-len"
      (toString vllm.maxModelLen)
      "--gpu-memory-utilization"
      (toString vllm.gpuMemoryUtilization)
      "--dtype"
      vllm.dtype
    ]
    ++ optional vllm.trustRemoteCode "--trust-remote-code"
    ++ vllm.extraArgs;

  cacheEnvironment = {
    HF_HOME = "${cfg.dataDir}/huggingface";
    VLLM_CACHE_ROOT = "${cfg.dataDir}/vllm";
  };

  rocmEnvironment = optionalAttrs vllm.rocm.enableCompat {
    HSA_OVERRIDE_GFX_VERSION = vllm.rocm.hsaOverrideGfxVersion;
    PYTORCH_ROCM_ARCH = vllm.rocm.pytorchRocmArch;
    HIP_VISIBLE_DEVICES = "0";
  };

  offlineEnvironment = optionalAttrs vllm.offline {
    HF_HUB_OFFLINE = "1";
    TRANSFORMERS_OFFLINE = "1";
  };
in {
  config = mkMerge [
    {
      assertions = [
        {
          assertion = !(cfg.enable && cfg.backend == "vllm" && cfg.embedding.enable);
          message = "laplace.services.llm.embedding.enable currently requires backend = \"llama-cpp\".";
        }
        {
          assertion =
            !(cfg.enable && cfg.backend == "vllm" && vllm.modelSource != null)
            || (let
              model = vllm.modelRegistry.${vllm.modelSource};
            in
              model.files != {} || (model.url != null && model.rev != null && model.hash != null));
          message = "laplace.services.llm.vllm.modelSource must refer to a modelRegistry entry with either files or url/rev/hash.";
        }
      ];
    }

    (mkIf (cfg.enable && cfg.backend == "vllm") {
      system.extraDependencies = optional (vllm.modelSource != null) activeModel;

      users.groups.llm = {};
      users.users.llm = {
        isSystemUser = true;
        group = "llm";
        extraGroups = [
          "render"
          "video"
        ];
      };

      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0750 llm llm - -"
        "d ${cfg.dataDir}/huggingface 0750 llm llm - -"
        "d ${cfg.dataDir}/vllm 0750 llm llm - -"
      ];

      systemd.services.vllm = {
        description = "vLLM OpenAI-compatible server";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        environment = cacheEnvironment // rocmEnvironment // offlineEnvironment // vllm.environment;

        serviceConfig =
          {
            Type = "simple";
            User = "llm";
            Group = "llm";
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${vllm.package}/bin/vllm ${utils.escapeSystemdExecArgs serveArgs}";
            Restart = "on-failure";
            RestartSec = 30;
            UMask = "0027";

            # GPU acceleration needs /dev/kfd and /dev/dri access.
            PrivateDevices = false;

            # PyTorch/vLLM runtime breaks under llama.cpp-level hardening.
            CapabilityBoundingSet = "";
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
              "AF_UNIX"
            ];
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHome = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectSystem = "full";
            ReadWritePaths = [cfg.dataDir];
            RemoveIPC = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";
          }
          // optionalAttrs (vllm.environmentFile != null) {
            EnvironmentFile = vllm.environmentFile;
          };
      };

      networking.firewall.allowedTCPPorts = optional vllm.openFirewall vllm.port;
    })
  ];
}
