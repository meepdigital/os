# Ten database strategies for a singular Meep state

1. **SQLite state capsule.** Keep an offline-first per-user database for menus, shortcuts, themes, panels, window layouts, installed modules, and sync cursors. Use WAL mode and schema migrations.
2. **PostgreSQL control plane.** Store tenant, device, policy, package, and repository state centrally with row-level security. Clients cache a signed snapshot for offline use.
3. **MySQL per-user state service.** Use normalized tables for the complete UI model and stored procedures for idempotent “install”, “enable menu”, “restore profile”, and “reconcile device” operations.
4. **Redis event/state layer.** Publish window, panel, torrent, and install events; use streams for durable replay and short TTL keys for presence and running-program state.
5. **Aurora/RDS regional state.** Put durable hosted account/device metadata in managed relational storage, with read replicas for login bootstrap and explicit regional failover.
6. **DynamoDB device projections.** Store append-only device mutations keyed by user/device and project them into fast current-state records. Conditional writes prevent two machines from silently winning.
7. **Torrented query cache.** Publish signed, immutable package/menu/module indexes as torrentable snapshots. Clients query SQLite locally and fetch only a new snapshot when its content hash changes.
8. **Database-backed configuration compiler.** Store declarative settings, resolve policy precedence in SQL routines, and compile a device-specific `/etc` and Cinnamon profile. Keep the source model separate from generated files.
9. **Unified artifact registry.** Give every ISO, squashfs, npm module, `.node` addon, C helper, theme, and menu entry a digest, provenance, ABI, license, and revocation status in one registry.
10. **Event-sourced singularity.** Treat installs, logins, file restores, shortcut changes, torrent subscriptions, and app launches as signed events. Materialized views power the desktop; replay and comparison explain every state change.

Never store plaintext passwords, AD secrets, OAuth refresh tokens, or private keys in these databases. Use Secret Service/HSM/KMS references, encrypt transport and backups, and make a local safe mode available when the hosted database is unavailable.

