# Caddy for internal services

Node-local Caddy provides stable application origins and TLS via Cloudflare
DNS-01 without publishing public A records. The shared engine, ACME identity and
certificate credential stay machine facilities; each cluster recipe owns its
individual routes, upstream, headers and public-origin setting.

Tailnet policy authorizes addresses/ports, not HTTP vhosts. A grant to one
service's shared IP:443 also reaches the other vhosts at the network layer.
Application authorization and Syncthing's explicit owner-source proxy gate are
therefore required. Disabling one route must not remove another owner's access
or the shared Caddy state.

AdGuard Home suppresses Caddy's automatic HTTP-to-HTTPS redirect listener only
when its application port is 80, to avoid competing for the same socket. Moving
AdGuard to another port (for example, 8080) leaves automatic redirects enabled,
so colocated services keep their declared HTTP endpoints. This recipe option
merges with, rather than replaces, other Caddy global settings.

NocoDB's domain/DNS record intentionally does not create a Caddy route. Forgejo
and Headscale instead use the declared Portunus edge with scoped LAN backends.
See [cluster network semantics](cluster.md#network-semantics).

## Redirect regression check

```sh
nix build --no-link .#checks.x86_64-linux.cluster-adguard-caddy
```

This check runs Caddy with evaluated AdGuard-on-80 and AdGuard-on-8080 plus
Miniflux projections. It uses internal TLS and unprivileged listener ports, with
no production credentials or application daemons. It checks HTTP refusal in the
conflicting case, the Miniflux redirect status and destination otherwise, and an
independent global header-size limit through live HTTPS requests.

The original-port fixtures are exported as `adguardCaddy.on80` and
`adguardCaddy.on8080` from `nix/tests/personal-services.nix`. For a smoke on
ports 80/443, reuse their evaluated modules and the check's internal-TLS
substitution without its listener remapping. Run in an isolated network
namespace with permission to bind privileged ports; the fixtures need no
Cloudflare token or upstream application to exercise redirects.
