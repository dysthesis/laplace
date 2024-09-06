{
  #   inputs,
  #   systemConfig,
  #   lib,
  #   config,
  #   ...
  # }: let
  #   inherit (lib) mkIf;
  #   cfg = systemConfig.laplace.features.impermanence;
  # in {
  #   imports = [inputs.impermanence.nixosModules.home-manager.impermanence];
  #
  #   home.persistence = mkIf cfg.enable {
  #     "${cfg.persistDir}/home/${config.home.username}" = {
  #       allowOther = true;
  #       directories = [
  #         "Documents"
  #         "Downloads"
  #         "Music"
  #         "Pictures"
  #         "Sync"
  #         ".local/share/direnv"
  #         ".gnupg"
  #         ".ssh"
  #         ".local/share/keyrings"
  #       ];
  #     };
  #   };
}
