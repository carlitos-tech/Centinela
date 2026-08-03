#!/usr/bin/env bash
#
# Valida las plantillas Bicep de Centinela (Fase 03) sin desplegar ningún recurso.
#
# Este script SOLO ejecuta: az bicep version, az bicep build, az bicep lint y
# az deployment sub validate. NUNCA ejecuta az deployment sub create, az deployment group create,
# az group create, az resource create/update/delete, az provider register, ni ningún comando con
# --confirm-with-what-if para aplicar cambios. Si necesitas agregar un paso nuevo a este script,
# no agregues ninguno de los comandos anteriores sin una autorización humana explícita separada.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
infra_dir="$(cd "${script_dir}/.." && pwd)"
main_template="${infra_dir}/main.bicep"
params_file="${infra_dir}/dev.bicepparam"

echo '== az bicep version =='
az bicep version

echo '== az bicep build (main.bicep) =='
az bicep build --file "${main_template}"

echo '== az bicep lint (main.bicep) =='
az bicep lint --file "${main_template}"

read -r -p 'Usuario administrador temporal de Azure SQL (solo para validate, no se guarda): ' sql_admin_login
read -r -s -p 'Contraseña temporal de administrador de Azure SQL (solo en memoria, no se guarda): ' sql_admin_password
echo

# dev.bicepparam lee estas dos variables vía readEnvironmentVariable(); nunca se pasan como
# argumento de línea de comandos ni quedan escritas en disco.
export CENTINELA_SQL_ADMIN_LOGIN="${sql_admin_login}"
export CENTINELA_SQL_ADMIN_PASSWORD="${sql_admin_password}"

cleanup() {
    unset sql_admin_login sql_admin_password CENTINELA_SQL_ADMIN_LOGIN CENTINELA_SQL_ADMIN_PASSWORD
}
trap cleanup EXIT

echo '== az deployment sub validate (East US 2) =='
az deployment sub validate \
    --location eastus2 \
    --template-file "${main_template}" \
    --parameters "${params_file}" \
    --only-show-errors

echo 'Validación completa. No se creó, modificó ni eliminó ningún recurso de Azure.'
