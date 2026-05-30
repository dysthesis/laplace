# Based on the linux-hardened configuration formerly carried by nixpkgs.
{
  stdenv,
  lib,
  version,
}: let
  inherit (lib.kernel) freeform no option yes;
  inherit
    (lib.kernel.whenHelpers version)
    whenAtLeast
    whenOlder
    ;
in {
  SECURITY_SELINUX_DISABLE = whenOlder "6.4" no;
  SECURITY_WRITABLE_HOOKS = option no;

  DEBUG_CREDENTIALS = whenOlder "6.6" yes;
  DEBUG_NOTIFIERS = yes;
  DEBUG_PI_LIST = whenOlder "5.2" yes;
  DEBUG_PLIST = whenAtLeast "5.2" yes;
  DEBUG_SG = yes;
  DEBUG_VIRTUAL = yes;
  SCHED_STACK_END_CHECK = yes;

  REFCOUNT_FULL = whenOlder "5.4.208" yes;
  RESET_ATTACK_MITIGATION = yes;
  CONFIG_LDISC_AUTOLOAD = option no;
  PAGE_POISONING_NO_SANITY = whenOlder "5.11" yes;
  PAGE_POISONING_ZERO = whenOlder "5.11" yes;
  INIT_ON_FREE_DEFAULT_ON = whenAtLeast "5.3" yes;
  ZERO_CALL_USED_REGS = whenAtLeast "5.15" yes;
  SECURITY_SAFESETID = whenAtLeast "5.1" yes;
  PANIC_TIMEOUT = freeform "-1";

  GCC_PLUGINS = yes;
  GCC_PLUGIN_STRUCTLEAK = option yes;
  GCC_PLUGIN_STRUCTLEAK_BYREF_ALL = option yes;
  GCC_PLUGIN_STACKLEAK = whenAtLeast "4.20" (option yes);
  GCC_PLUGIN_RANDSTRUCT = whenOlder "5.19" yes;
  GCC_PLUGIN_RANDSTRUCT_PERFORMANCE = whenOlder "5.19" yes;

  UBSAN = yes;
  UBSAN_TRAP = whenAtLeast "5.7" yes;
  UBSAN_BOUNDS = whenAtLeast "5.7" yes;
  UBSAN_SANITIZE_ALL = whenOlder "6.9" yes;
  UBSAN_LOCAL_BOUNDS = option yes;
  CFI_CLANG = option yes;

  ACPI_CUSTOM_METHOD = whenOlder "6.9" no;
  PROC_KCORE = no;
  INET_DIAG = no;
  INET_DIAG_DESTROY = option no;
  INET_RAW_DIAG = option no;
  INET_TCP_DIAG = option no;
  INET_UDP_DIAG = option no;
  INET_MPTCP_DIAG = option no;

  CC_STACKPROTECTOR_REGULAR = lib.mkForce (whenOlder "4.18" no);
  CC_STACKPROTECTOR_STRONG = whenOlder "4.18" yes;

  STRICT_DEVMEM = option no;
  IO_STRICT_DEVMEM = option no;
  IOMMU_DEFAULT_DMA_STRICT = option yes;
  IOMMU_DEFAULT_DMA_LAZY = option no;
  LEGACY_VSYSCALL_NONE = lib.mkIf stdenv.hostPlatform.isx86 yes;
}
