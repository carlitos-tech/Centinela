# Convenciones de commits — Centinela

Se usa [Conventional Commits](https://www.conventionalcommits.org/).

## Formato

```text
tipo(alcance-opcional): descripción breve en presente

Cuerpo opcional con más contexto.
```

## Tipos permitidos

| Tipo | Uso |
|------|-----|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de errores |
| `chore` | Tareas de mantenimiento, configuración, gobierno |
| `docs` | Cambios de documentación |
| `refactor` | Cambios de código sin alterar comportamiento |
| `test` | Adición o ajuste de pruebas |
| `ci` | Cambios en workflows de integración/validación |
| `build` | Cambios en dependencias o empaquetado |

## Ejemplos usados en este proyecto

- `chore: bootstrap repository`
- `chore: establish repository governance`

## Reglas

- Mensajes en minúscula, modo imperativo, sin punto final en la línea de asunto.
- Un commit debe representar un cambio coherente y revisable.
- No se incluyen valores sensibles en los mensajes de commit.
