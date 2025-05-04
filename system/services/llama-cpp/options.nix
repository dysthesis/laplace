{lib, ...}: {
  options.laplace.services.llama-cpp = {
    enable =
      (lib.mkEnableOption "LLaMa.cpp")
      // {
        default = true;
      };
    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    port = lib.mkOption {
      type = lib.types.int;
      default = 13810;
    };

    modelName = lib.mkOption {
      type = lib.types.str;
      default = "Mistral-Small-3.1-24B-Instruct-2503-bf16.gguf";
    };
  };
}
