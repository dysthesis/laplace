{
  rustPlatform,
  fetchFromGitHub,
  # installShellFiles,
  ...
}:
rustPlatform.buildRustPackage rec {
  pname = "bmm";
  version = "0.3.0";
  src = fetchFromGitHub {
    owner = "dhth";
    repo = "bmm";
    rev = "v${version}";
    sha256 = "sha256-sfAUvvZ/LKOXfnA0PB3LRbPHYoA+FJV4frYU+BpC6WI=";
  };
  cargoHash = "sha256-+o8bYi4Pe9zwiDBUMllpF+my7gp3iLX0+DntFtN7PoI=";
  # nativeBuildInputs = [installShellFiles];
  doCheck = false;
}
