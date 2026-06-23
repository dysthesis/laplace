# Reverse-path filter testing

This refuses packets if a reply to it would not be sent from the same interface
it arrived on. This is relaxed to `"loose"` on Tailnet hosts to support
Tailscale's asymmetric routing trips (strict RPF), while kept as `"strict"`
otherwise.
