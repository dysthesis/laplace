{
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  ...
}:
rustPlatform.buildRustPackage rec {
  pname = "taskwarrior-tui";
  # Last working version with taskwarrior 2
  version = "0.25.4";
  src = fetchFromGitHub {
    owner = "kdheepak";
    repo = "taskwarrior-tui";
    rev = "v${version}";
    sha256 = "sha256-M8tiEUPfP5EWfPp7i6r0lpHC5ZUsEYeEKVz5gUpe4+A=";
  };
  cargoHash = "sha256-HLygJDtea2E8m3KG8IvJBEH69Bi6Ojm+d21904ISpys=";
  nativeBuildInputs = [ installShellFiles ];

  # Because there's a test that requires terminal access
  doCheck = false;

  postInstall = ''
    installManPage docs/taskwarrior-tui.1
    installShellCompletion completions/taskwarrior-tui.{bash,fish} --zsh completions/_taskwarrior-tui
  '';
}
