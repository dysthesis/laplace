# The lifecycle VM checks the generated IPv6 proxy.
{lib}: let
  common = import ../../system/services/service-common.nix {inherit lib;};
  dial = address:
    common.dial "127.0.0.1" {
      listenAddress = address;
      port = 8087;
    };
  checks = {
    ipv4Wildcard = dial "0.0.0.0" == "127.0.0.1:8087";
    specificIPv4 = dial "192.0.2.17" == "192.0.2.17:8087";
    ipv6Wildcard = dial "::" == "[::1]:8087";
    bracketedWildcard = dial "[::]" == "[::1]:8087";
    specificIPv6 = dial "fd00::17" == "[fd00::17]:8087";
    bracketedIPv6 = dial "[fd00::17]" == "[fd00::17]:8087";
    bindStaysWildcard = common.hostPort "::" 8087 == "[::]:8087";
  };
in
  assert lib.all (value: value) (builtins.attrValues checks); checks
