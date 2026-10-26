# Hosts

`cluster/machines.nix` owns platform, explicit role, deployability, cross-host
addresses, Tailnet identity and node consumer participation. These directories
own machine-specific interfaces, gateways, hardware, provisioned storage,
VM resources, local resolver behavior, writer credentials and shared facilities.
Applications are declared only in the cluster service modules.

| Class            | Machines                                                                            |
| ---------------- | ----------------------------------------------------------------------------------- |
| Trusted servers  | Apollo, Argus, Charon, Hermes, Horos, Mimir, Mneme                                  |
| Isolated servers | Bifrost (control plane), Hephaestus (git), Loki (game), Portunus (edge), Talos (CI) |
| Workstations     | Deimos (PC), Phobos (Framework laptop)                                              |
| Installer        | Chaos                                                                               |

Only deployable servers accept applications. `proxmox` is a machine profile,
not a placement/security classification. External Tailnet peers are not hosts.
See [cluster operations](../docs/cluster.md); decommission applications while the
host is still a deployment target, before removing its role or inventory entry.
