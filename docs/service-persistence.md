# Service state persistence

With `DynamicUser` and `StateDirectory=<name>` enabled, the real persistence
directory lives in `/var/lib/private/<name>`. Thus, we configure `mnemosyne.dirs`
accordingly for these modules.

**TODO.** Automate the discovery of `DynamicUser` services and automatically set
`mnemosyne.dirs = ["/var/lib/private/<name>"]` accordingly.
