# CLAUDE.md — database/

Esta carpeta contendrá los scripts y modelos de base de datos de Centinela.

## Estado actual

**Sin SQL funcional.** Esta carpeta no debe contener scripts de creación de esquema, migraciones ni datos hasta que la fase correspondiente del plan sea explícitamente autorizada.

## Reglas cuando se autorice el desarrollo

- El modelo de datos debe reflejar únicamente entidades ficticias del caso de demostración NovaCasa S.A.S.
- No se incluyen datos reales de ninguna empresa o persona en scripts de carga o semillas (`seed`).
- No se incluyen cadenas de conexión ni credenciales en scripts versionados.
- Las migraciones deben ser reversibles cuando sea técnicamente posible.
- Cambios de esquema en producción requieren aprobación humana explícita.
