# Schema lifecycle

v1.0.0 is `../content.sql` + `../manifest.schema.json` + generated `app/assets/schema_contract.json`.
No migration mutates an imported original archive or installed official content.

Future incompatible content schema changes require a new schema version, a separate
read adapter, and explicit app capability negotiation. App-state migrations operate
only on user.sqlite with backup and a SQLite transaction. No state migration is
needed for the initial 0.1.0 build. NEVER regenerate indexes at application startup.
