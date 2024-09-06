{
  inputs,
  pkgs,
  ...
}: {
  programs.firefox.profiles.abaddon.extensions = with inputs.firefox-addons.packages.${pkgs.system}; [
    ublock-origin
    tabliss
    darkreader
    canvasblocker
    # bypass-paywalls-clean
    stylus
    vimium
    sidebery
  ];
}
