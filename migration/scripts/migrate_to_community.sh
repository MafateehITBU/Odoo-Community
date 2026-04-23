#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${ROOT_DIR}/migration_work"
SQL_CLEANUP="${ROOT_DIR}/migration/sql/enterprise_cleanup.sql"

ZIP_PATH=""
DB_NAME=""
ADMIN_DB_USER="postgres"
APP_DB_USER="odoo18"
DB_HOST="localhost"
DB_PORT="5432"
ADMIN_DB_PASS=""
APP_DB_PASS="odoo18"
ODOO_BIN=""
ODOO_PYTHON="python3"
ADDONS_PATH=""
DATA_DIR=""
WORKERS="0"

usage() {
  cat <<'EOF'
Usage:
  migrate_to_community.sh --zip <backup.zip> --db <db_name> --odoo-bin <odoo-bin> --addons <addons_path> --data-dir <odoo_data_dir> [options]

Required:
  --zip        Absolute path to Odoo.sh backup zip
  --db         Target database name
  --odoo-bin   Absolute path to Odoo 18 Community odoo-bin
  --addons     Comma-separated addons path (at least core addons)
  --data-dir   Odoo data directory (holds filestore)

Optional:
  --admin-db-user PostgreSQL admin user for restore (default: postgres)
  --app-db-user   PostgreSQL app user for Odoo login (default: odoo18)
  --db-host    PostgreSQL host (default: localhost)
  --db-port    PostgreSQL port (default: 5432)
  --admin-db-pass PostgreSQL admin password (optional)
  --app-db-pass   PostgreSQL app user password (default: odoo18)
  --python     Python binary to run odoo-bin (default: python3)
  --workers    Odoo workers for upgrade step (default: 0)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --zip) ZIP_PATH="$2"; shift 2 ;;
    --db) DB_NAME="$2"; shift 2 ;;
    --admin-db-user) ADMIN_DB_USER="$2"; shift 2 ;;
    --app-db-user) APP_DB_USER="$2"; shift 2 ;;
    --db-host) DB_HOST="$2"; shift 2 ;;
    --db-port) DB_PORT="$2"; shift 2 ;;
    --admin-db-pass) ADMIN_DB_PASS="$2"; shift 2 ;;
    --app-db-pass) APP_DB_PASS="$2"; shift 2 ;;
    --python) ODOO_PYTHON="$2"; shift 2 ;;
    --odoo-bin) ODOO_BIN="$2"; shift 2 ;;
    --addons) ADDONS_PATH="$2"; shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    --workers) WORKERS="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "${ZIP_PATH}" || -z "${DB_NAME}" || -z "${ODOO_BIN}" || -z "${ADDONS_PATH}" || -z "${DATA_DIR}" ]]; then
  usage
  exit 1
fi

if [[ ! -f "${ZIP_PATH}" ]]; then
  echo "Backup zip not found: ${ZIP_PATH}"
  exit 1
fi
if [[ ! -f "${ODOO_BIN}" ]]; then
  echo "odoo-bin not found: ${ODOO_BIN}"
  exit 1
fi
if ! command -v "${ODOO_PYTHON}" >/dev/null 2>&1; then
  echo "Python binary not found in PATH: ${ODOO_PYTHON}"
  exit 1
fi
if [[ ! -f "${SQL_CLEANUP}" ]]; then
  echo "Cleanup SQL not found: ${SQL_CLEANUP}"
  exit 1
fi

mkdir -p "${WORK_DIR}" "${DATA_DIR}/filestore"

echo "[1/8] Extracting dump.sql and filestore..."
unzip -o "${ZIP_PATH}" dump.sql -d "${WORK_DIR}" >/dev/null
unzip -o "${ZIP_PATH}" "filestore/*" -d "${WORK_DIR}" >/dev/null

echo "[2/8] Sanitizing dump for PostgreSQL client compatibility..."
sed -E '/^\\(un)?restrict /d' "${WORK_DIR}/dump.sql" > "${WORK_DIR}/dump_sanitized.sql"

export PGPASSWORD="${ADMIN_DB_PASS}"
ADMIN_PSQL=(psql -v ON_ERROR_STOP=1 -h "${DB_HOST}" -p "${DB_PORT}" -U "${ADMIN_DB_USER}")

echo "[3/8] Recreating database ${DB_NAME}..."
dropdb --if-exists -h "${DB_HOST}" -p "${DB_PORT}" -U "${ADMIN_DB_USER}" "${DB_NAME}"
createdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${ADMIN_DB_USER}" "${DB_NAME}"

echo "[3.5/8] Preparing dedicated Odoo DB user..."
ROLE_EXISTS="$("${ADMIN_PSQL[@]}" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='${APP_DB_USER}'")"
if [[ "${ROLE_EXISTS}" != "1" ]]; then
  "${ADMIN_PSQL[@]}" -d postgres -c "CREATE ROLE \"${APP_DB_USER}\" LOGIN PASSWORD '${APP_DB_PASS}';"
else
  "${ADMIN_PSQL[@]}" -d postgres -c "ALTER ROLE \"${APP_DB_USER}\" LOGIN PASSWORD '${APP_DB_PASS}';"
fi

echo "[4/8] Restoring SQL dump..."
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -f "${WORK_DIR}/dump_sanitized.sql" >/dev/null

echo "[4.5/8] Granting DB ownership to app user..."
"${ADMIN_PSQL[@]}" -d postgres -v db_name="${DB_NAME}" -v app_user="${APP_DB_USER}" <<'SQL'
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = :'db_name' AND pid <> pg_backend_pid();
SELECT format('ALTER DATABASE %I OWNER TO %I', :'db_name', :'app_user') \gexec
SELECT format('GRANT ALL PRIVILEGES ON DATABASE %I TO %I', :'db_name', :'app_user') \gexec
SQL
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "REASSIGN OWNED BY \"${ADMIN_DB_USER}\" TO \"${APP_DB_USER}\";"
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"${APP_DB_USER}\";"
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO \"${APP_DB_USER}\";"
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO \"${APP_DB_USER}\";"

echo "[5/8] Applying enterprise cleanup SQL..."
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -f "${SQL_CLEANUP}"
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "DROP SEQUENCE IF EXISTS base_registry_signaling, base_cache_signaling, base_cache_signaling_assets, base_cache_signaling_default, base_cache_signaling_groups, base_cache_signaling_routing, base_cache_signaling_templates;"

echo "[6/8] Syncing filestore..."
rm -rf "${DATA_DIR}/filestore/${DB_NAME}"
cp -R "${WORK_DIR}/filestore" "${DATA_DIR}/filestore/${DB_NAME}"

echo "[7/8] Running Odoo 18 Community upgrade..."
"${ODOO_PYTHON}" "${ODOO_BIN}" \
  -d "${DB_NAME}" \
  --db_host="${DB_HOST}" \
  --db_port="${DB_PORT}" \
  --db_user="${APP_DB_USER}" \
  --db_password="${APP_DB_PASS}" \
  --addons-path="${ADDONS_PATH}" \
  --data-dir="${DATA_DIR}" \
  --workers="${WORKERS}" \
  --without-demo=all \
  -u all \
  --stop-after-init

echo "[8/8] Post-check: installed enterprise-like modules"
"${ADMIN_PSQL[@]}" -d "${DB_NAME}" -c "
SELECT name, state
FROM ir_module_module
WHERE state = 'installed'
  AND (name ~ '(enterprise|studio|helpdesk|documents|knowledge|spreadsheet|sign|planning|voip)'
       OR name IN ('web_enterprise'))
ORDER BY name;
"

echo "Migration completed for database: ${DB_NAME}"
