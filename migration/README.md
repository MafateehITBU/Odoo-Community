# Odoo.sh Enterprise -> Odoo 18 Community Migration (No Docker)

This folder provides a repeatable migration workflow for your backup:

- restore the Odoo.sh dump
- extract and attach filestore
- neutralize Enterprise-only modules and metadata
- run Odoo 18 Community upgrade
- validate and troubleshoot common startup errors

## 1) Prerequisites (local machine)

- PostgreSQL 16 client/server (`psql`, `createdb`, `dropdb`)
- Python virtualenv for Odoo 18 Community
- Odoo 18 Community source code path (local clone)

## 2) Folder layout expected by scripts

The scripts expect:

- backup zip: `mafateeh-it-mafateeh-main-13315049_2026-04-21_182732_exact_fs.zip`
- SQL dump path after extract: `migration_work/dump.sql`
- filestore path after extract: `migration_work/filestore`

## 3) One-command migration

Use:

```bash
./migration/scripts/migrate_to_community.sh \
  --zip "/absolute/path/to/mafateeh-it-mafateeh-main-13315049_2026-04-21_182732_exact_fs.zip" \
  --db mafateeh_community18 \
  --odoo-bin "/absolute/path/to/odoo/odoo-bin" \
  --python "/absolute/path/to/venv/bin/python" \
  --addons "/absolute/path/to/odoo/addons" \
  --data-dir "/absolute/path/to/odoo-data" \
  --admin-db-user postgres \
  --app-db-user odoo18 \
  --app-db-pass odoo18
```

Optional flags:

- `--admin-db-user postgres` (default: `postgres`)
- `--admin-db-pass <pass>` (optional)
- `--app-db-user odoo18` (default: `odoo18`)
- `--app-db-pass odoo18` (default: `odoo18`)
- `--db-host localhost` (default: `localhost`)
- `--db-port 5432` (default: `5432`)
- `--workers 0` (default: `0`)

## 4) What the migration script does

1. Extracts `dump.sql` and `filestore/` from zip.
2. Drops/recreates target DB.
3. Restores SQL dump.
4. Runs `migration/sql/enterprise_cleanup.sql`.
5. Copies filestore to `<data-dir>/filestore/<db_name>`.
6. Runs Odoo 18 Community with `-u all --stop-after-init`.
7. Prints post-check queries for remaining enterprise traces.

## 5) Common error fixes

- Missing Python dependency:
  - install from Odoo requirements: `pip install -r requirements.txt`
- `relation ... does not exist` during upgrade:
  - rerun migration script (cleanup + upgrade)
  - check module state query in section 6
- View parse error referencing enterprise model/field:
  - ensure `enterprise_cleanup.sql` executed successfully
  - rerun `-u all --stop-after-init`
- Filestore access errors:
  - ensure `<data-dir>/filestore/<db_name>` exists and user has read/write

## 6) Validation queries

Run after migration:

```sql
-- Enterprise-like modules still installed
SELECT name, state, latest_version
FROM ir_module_module
WHERE state = 'installed'
  AND (
    name ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)'
    OR name IN ('web_enterprise')
  )
ORDER BY name;

-- XML IDs still coming from enterprise modules
SELECT module, count(*)
FROM ir_model_data
WHERE module ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)'
   OR module IN ('web_enterprise')
GROUP BY module
ORDER BY count(*) DESC;
```

## 7) Recommended production hardening after successful start

- create a clean Odoo 18 Community config file
- disable db_manager on exposed interfaces
- set proxy mode only if behind reverse proxy
- run with workers > 0 only after successful dry run
- take a fresh DB backup after first successful startup
