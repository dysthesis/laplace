{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (builtins) replaceStrings;
  inherit (lib) concatMapStringsSep;
  # Quotes an argument for use in Exec* service lines.
  # systemd accepts "-quoted strings with escape sequences, toJSON produces
  # a subset of these.
  # Additionally we escape % to disallow expansion of % specifiers. Any lone ;
  # in the input will be turned it ";" and thus lose its special meaning.
  # Every $ is escaped to $$, this makes it unnecessary to disable environment
  # substitution for the directive.
  escapeSystemdExecArg =
    arg:
    let
      s =
        if builtins.isPath arg then
          "${arg}"
        else if builtins.isString arg then
          arg
        else if builtins.isInt arg || builtins.isFloat arg then
          toString arg
        else
          throw "escapeSystemdExecArg only allows strings, paths and numbers";
    in
    replaceStrings [ "%" "$" ] [ "%%" "$$" ] (builtins.toJSON s);

  # Quotes a list of arguments into a single string for use in a Exec*
  # line.
  escapeSystemdExecArgs = concatMapStringsSep " " escapeSystemdExecArg;
  model = pkgs.linkFarm "llama-model" {
    "Mistral-Small-3.1-24B-Instruct-2503-bf16.gguf" = pkgs.fetchurl {
      name = "Mistral-Small-3.1-24B-Instruct-2503-bf16.gguf";
      url = "https://huggingface.co/bartowski/mistralai_Mistral-Small-3.1-24B-Instruct-2503-GGUF/resolve/main/mistralai_Mistral-Small-3.1-24B-Instruct-2503-bf16.gguf?download=true";
      sha256 = "sha256-tLiuJKc2TjxTWzhU3h0jUcXxLgDXu11vsJQYOJGjcnY=";
    };
  };
  cfg = config.laplace.services.llama-cpp;
  llamacppConfig = config.services.llama-cpp;
  inherit (cfg) modelName;
  inherit (lib) mkIf;
in
{
  config = mkIf cfg.enable {
    services.llama-cpp = {
      enable = false;

      package = pkgs.llama-cpp.override {
        rocmSupport = true;
        openclSupport = true;
      };
      inherit (cfg) port host;
      extraFlags =
        let
          concurrency = 4;
        in
        [
          "-c"
          "${builtins.toString (concurrency * 2048)}"
          "-ngl"
          "100"
          "-np"
          "${builtins.toString concurrency}"
          "-cb"
          "-fa"
          "--metrics"
          "-sm"
          "none"
        ];
    };

    systemd.services.llama-cpp = {
      description = "LLaMA C++ server";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ curl ];
      postStart = ''
        curl \
          --fail \
          --retry 30 \
          --retry-delay 5 \
          --retry-max-time 120 \
          --retry-all-errors \
          http://${cfg.host}:${builtins.toString cfg.port}/health
      '';

      serviceConfig = {
        Type = "idle";
        KillSignal = "SIGINT";
        ExecStart = "${llamacppConfig.package}/bin/llama-server --log-disable --host ${llamacppConfig.host} --port ${builtins.toString cfg.port} -m ${modelName} ${escapeSystemdExecArgs llamacppConfig.extraFlags}";
        Restart = "on-failure";
        RestartSec = 300;
        WorkingDirectory = "${model}";

        User = "llama-cpp";
        Group = "llama-cpp";

        # for GPU acceleration
        PrivateDevices = false;
      };
    };

    users.users.llama-cpp = {
      group = "llama-cpp";
      isSystemUser = true;
    };
    users.groups.llama-cpp = { };
  };
}
