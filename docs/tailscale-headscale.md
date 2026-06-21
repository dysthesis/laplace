Tailscale and Headscale
=======================

We connect the infra together via Tailscale, with a self-hosted Headscale as 
the coordination server. The Headscale instance is hosted on host `bifrost`, and
is the only component of this network that is accessible via the public internet
and thus acts as a chokepoint. It alone introduces new members to the Tailnet,
manages access control, etc.

Access control
--------------

Headscale manages who can talk to who via Tailscale ACL. This is defined
declaratively with the `laplace.services.headscale.acl.*` options. We first 
define what _assets_ exist -- our Tailnet nodes, in 
`laplace.services.headscale.acl.hosts.*`, in the form of `<tailnet-ip>/32`.
Then, we define _how_ people can access these assets via a whitelist in 
`laplace.services.headscale.acl.groups.*`; each group contains `member`, listing
the users who are part of this group, and the `destinations` they are allowed to
reach, in the form of `<host>:<port>` (where `<host>` is a host previously 
defined in `laplace.services.headscale.acl.hosts.*`).

Hygiene
-------

Machines on the DMZ, which is exposed to the public internet, _must never_ be
introduced into the Tailnet, as it breaks the compartementalisation of the VLANs
and allows an avenue for pivoting.

Note that one issue with this is that Headscale _itself_ is in the DMZ, and it
is the sole authority for introducing new machines into the Tailnet. However,
this helps with isolating private machines from any break-ins in the DMZ as long
as it's not on Headscale itself.

Management UI
-------------

Headplane is a management UI for Headscale, accessible only _inside_ the Tailnet
at `headplane.dysthesis.com`. It is hosted in `bifrost` as well.

**TODO.** Consider separating them into a different host, or moving Headplane to
`mimir`, as Headplane is a strictly private service, thus mixing it with the DMZ
is probably a bad idea (gives a publicly-exposed node an entryway into the 
Tailnet if it is compromised).


Minor thoughts
--------------

In theory, a cleaner architecture for a coordination server would be to split 
the _introducer_ and the _manager_. The former strictly needs to be exposed to
the public internet, in order to coordinate with new devices; the latter does 
not, and strictly works with nodes who are _already_ in the Tailnet.
