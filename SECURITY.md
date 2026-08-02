# Política de seguridad — Centinela

## Alcance

Centinela es un proyecto de demostración (hackathon) que utiliza exclusivamente datos ficticios de una pyme inventada, **NovaCasa S.A.S.**. No procesa datos reales de clientes, empleados ni de ninguna organización real.

## Reglas de seguridad del repositorio

- No se versionan secretos, tokens, llaves privadas, certificados ni cadenas de conexión.
- No se versionan archivos `.env` con valores reales (solo `.env.example` con placeholders).
- No se versiona `.claude/settings.local.json`.
- No se incluyen correos personales, rutas locales completas del equipo de desarrollo, nombres de empresas reales, ni identificadores completos de Tenant ID / Subscription ID de Azure en ningún archivo versionado.
- Todo commit y push pasa por un escaneo de seguridad previo (manual y, cuando GitHub lo permite, automatizado vía secret scanning y push protection).

## Reporte de vulnerabilidades

Al ser un proyecto de demostración de un solo desarrollador, no existe un canal de soporte externo. Cualquier hallazgo de seguridad debe registrarse como un issue en este repositorio con la etiqueta `security`, evitando incluir en el propio issue cualquier valor sensible descubierto (solo describir el tipo de hallazgo y su ubicación).

## Funciones de seguridad de GitHub

Este repositorio busca habilitar, en la medida en que el plan de GitHub lo permita:

- Secret scanning
- Push protection
- Dependabot alerts
- Bloqueo de force-push y de eliminación en ramas protegidas

Cualquier función no disponible en el plan actual se registra explícitamente en `docs/evidence/` en lugar de asumirse como activa.

## Azure

Todo acceso a Azure se realiza mediante Azure CLI autenticado localmente por el desarrollador. No se almacenan credenciales de Azure en el repositorio. Los cambios de infraestructura se validan (`what-if`) antes de aplicarse y no se ejecutan eliminaciones o cambios de permisos sin aprobación humana explícita.
