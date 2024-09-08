{
  services.gnome-keyring.enable = true;

  # `login` means TTY login
  security.pam.services.login.enableGnomeKeyring = true;
}
