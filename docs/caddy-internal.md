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

NocoDB's domain/DNS record intentionally does not create a Caddy route. Forgejo
and Headscale instead use the declared Portunus edge with scoped LAN backends.
See [cluster network semantics](cluster.md#network-semantics).
