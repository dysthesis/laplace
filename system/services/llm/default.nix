{
  config,
  lib,
  ...
}: {
  imports = [
    ./options.nix
    ./llama-cpp.nix
    ./vllm.nix
    ./open-webui.nix
    ./perplexica.nix
  ];

  config = lib.mkIf config.laplace.services.llm.enable {
    mnemosyne.dirs = [
      "/var/lib/private/ollama"
      "/var/lib/private/open-webui"
      config.laplace.services.llm.dataDir
    ];
  };
}
