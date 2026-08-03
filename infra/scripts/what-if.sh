#!/usr/bin/env bash
#
# Ejecuta `az deployment sub what-if` sobre las plantillas Bicep de Centinela (Fase 03) para
# mostrar los cambios que se propondrían, sin aplicar ninguno.
#
# Este script SOLO ejecuta az deployment sub what-if (modo de solo lectura/preview de Azure CLI).
# NUNCA ejecuta az deployment sub create, az deployment group create, az group create,
# az resource create/update/delete, ni encadena `what-if` con `--confirm-with-what-if` para aplicar
# cambios automáticamente. Si necesitas agregar un paso nuevo a este script, no agregues ninguno de
# los comandos anteriores sin una autorización humana explícita separada.

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
infra_dir="$(cd "${script_dir}/.." && pwd)"
main_template="${infra_dir}/main.bicep"
params_file="${infra_dir}/dev.bicepparam"

read -r -p 'Usuario administrador temporal de Azure SQL (solo para what-if, no se guarda): ' sql_admin_login
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

echo '== az deployment sub what-if (East US 2) =='
az deployment sub what-if \
    --location eastus2 \
    --template-file "${main_template}" \
    --parameters "${params_file}" \
    --only-show-errors

echo 'what-if completo. Ningún cambio fue aplicado: este comando solo previsualiza.'
