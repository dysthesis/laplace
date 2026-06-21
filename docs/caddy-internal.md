Caddy for internal sevices
==========================

Inside Tailscale, we use Caddy as a reverse-proxy, which serves two purposes:

- the disambiguation of URLs, e.g. `tasks.dysthesis.com` rather than
  `mimir.tailnet.dysthesis.com:3456` -- useful especially given that some hosts,
  like `mimir`, hosts more than one services, and
- TLS via DNS-01; this is not for any security reason, just UX (so that browsers
  do not complain).

DNS-01 is used since internal services has no public A record. With that, we can
still obtain certificates.
