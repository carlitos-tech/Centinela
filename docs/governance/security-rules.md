# Reglas de seguridad — Centinela

## Datos

- Todo dato usado en el proyecto (usuarios, productos, conversaciones, documentos) es **ficticio**, asociado a la pyme inventada NovaCasa S.A.S.
- No se introduce información real de ninguna empresa (incluida cualquier organización real relacionada con el desarrollador) o persona.

## Secretos y credenciales

- No se versionan tokens, llaves privadas, certificados, cadenas de conexión ni contraseñas.
- No se versionan archivos `.env` con valores reales; solo `.env.example` con placeholders.
- No se versiona `.claude/settings.local.json`.

## Identificadores y rutas

- No se incluyen en archivos versionados: correos personales, rutas locales completas del equipo de desarrollo, Tenant ID o Subscription ID completos de Azure (se enmascaran cuando deban mencionarse).

## Proceso

- Escaneo de seguridad antes de cada `git init`, commit y push relevante, cubriendo las categorías anteriores.
- Ante un hallazgo sensible, el archivo no se agrega a git; se reporta únicamente el nombre del archivo y el tipo de información encontrada (nunca el valor), y se espera autorización antes de continuar.
- Uso, cuando el plan de GitHub lo permita, de secret scanning, push protection, Dependabot alerts y bloqueo de force-push/eliminación en ramas protegidas. Cualquier función no disponible se documenta como limitación, nunca se simula como activa.

## Azure

- Toda operación sobre Azure se realiza vía Azure CLI o Bicep, nunca manualmente ni con comandos improvisados.
- No se registran proveedores, no se crean recursos, no se cambian roles RBAC y no se eliminan recursos sin aprobación humana explícita y la fase correspondiente autorizada.
