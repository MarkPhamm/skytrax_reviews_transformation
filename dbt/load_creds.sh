#!/usr/bin/env bash
# Load Snowflake credentials into the current shell.
#
# Usage (must be sourced so exports persist):
#   source load_creds.sh          # loads cred_prod.txt
#   source load_creds.sh prod     # loads cred_prod.txt
#   . load_creds.sh staging       # loads cred_staging.txt

# Detect whether this file was sourced (required for exports to stick).
_is_sourced=0
if [[ -n "${ZSH_VERSION:-}" ]]; then
  case ${ZSH_EVAL_CONTEXT:-} in *:file*) _is_sourced=1 ;; esac
elif [[ -n "${BASH_VERSION:-}" ]]; then
  (return 0 2>/dev/null) && _is_sourced=1
fi

if [[ $_is_sourced -eq 0 ]]; then
  echo "Error: source this script so credentials persist in your shell:" >&2
  echo "  source load_creds.sh [env]" >&2
  exit 1
fi

# Resolve script directory in both bash and zsh when sourced.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  _script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _script_dir="$(cd "$(dirname "${(%):-%N}")" && pwd)"
else
  _script_dir="$(cd "$(dirname "$0")" && pwd)"
fi

_env_name="${1:-prod}"
_cred_file="${_script_dir}/cred_${_env_name}.txt"

if [[ ! -f "$_cred_file" ]]; then
  echo "Error: credential file not found: ${_cred_file}" >&2
  echo "Expected a file like cred_prod.txt with export SNOWFLAKE_* lines." >&2
  unset _is_sourced _script_dir _env_name _cred_file
  return 1
fi

# shellcheck disable=SC1090
source "$_cred_file"

echo "Loaded Snowflake credentials from cred_${_env_name}.txt"
echo "  SNOWFLAKE_USER=${SNOWFLAKE_USER:-<unset>}"
echo "  SNOWFLAKE_ROLE=${SNOWFLAKE_ROLE:-<unset>}"
echo "  SNOWFLAKE_SCHEMA=${SNOWFLAKE_SCHEMA:-<unset>}"
echo "  SNOWFLAKE_ACCOUNT=${SNOWFLAKE_ACCOUNT:-<unset>}"

unset _is_sourced _script_dir _env_name _cred_file
