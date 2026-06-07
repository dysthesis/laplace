{lib, ...}:
lib.laplace.modules.mkSelector {
  dir = ./.;
  option = ["laplace" "security" "privesc"];
  multiple = false;
  default = "sudo";
  description = "Which privilege escalation program to use.";
}
