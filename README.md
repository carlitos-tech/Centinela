# Centinela

Plataforma multiagente de atención al cliente con inteligencia artificial, construida como demostración de hackathon con Claude Code.

## Estado del proyecto

En construcción por fases. **Fase 02 — Walking skeleton local fusionada** ([Pull Request #4](https://github.com/carlitos-tech/Centinela/pull/4), fusionado). Issue de la fase: [#3](https://github.com/carlitos-tech/Centinela/issues/3) (cerrado). **Fase 03 — Azure CLI Command Gateway y Bicep IaC implementada y pendiente de aprobación humana** ([Pull Request #6](https://github.com/carlitos-tech/Centinela/pull/6), sin fusionar). Issue de la fase: [#5](https://github.com/carlitos-tech/Centinela/issues/5).

La Fase 02 entrega un recorrido completo **totalmente local**: Chat Web (Angular) → API (.NET) → `CustomerServiceOrchestrator` → `CustomerServicePlugin` → Skills → `FakeModelGateway` → catálogo/políticas ficticias de NovaCasa S.A.S. → respuesta fundamentada con citación de fuentes → traza de ejecución. **No usa Azure, no usa una base de datos real y no llama a ningún proveedor de IA real** — `FakeModelGateway` es una implementación local, determinista y sin dependencias externas de `IModelGateway`, usada como contingencia de desarrollo mientras no exista un proveedor de IA validado y autorizado (ver [ADR-003](docs/architecture/adr/ADR-003-model-gateway.md)). Detalle completo en el [reporte de evidencia de la Fase 02](docs/evidence/phase-02-walking-skeleton-report.md).

La Fase 03 agrega `IAzureCliCommandGateway` (única vía permitida para ejecutar Azure CLI desde el código de Centinela, con allowlist tipada de operaciones de solo lectura/validación, auditoría y redacción automática de salida) y plantillas Bicep de DEV validadas localmente (`bicep build`/`lint`, `deployment sub validate`/`what-if`). **No se creó ningún recurso de Azure, no se registró ningún proveedor y no se ejecutó ningún `deployment ... create`.** Detalle completo en el [reporte de evidencia de la Fase 03](docs/evidence/phase-03-azure-cli-gateway-iac-report.md).

## Empresa de referencia

**NovaCasa S.A.S.** es una pyme ficticia utilizada exclusivamente como caso de demostración. Todos los datos, usuarios, productos, documentos y conversaciones son ficticios. No se utiliza información real de ninguna empresa o persona.

## Arquitectura

```text
Proyecto → Agentes → Plugins → Skills → Artifacts
```

Ver [`docs/architecture/architecture-overview.md`](docs/architecture/architecture-overview.md) para el detalle completo.

## Ejecutar el walking skeleton local (Fase 02)

### Requisitos

- [.NET SDK 10](https://dotnet.microsoft.com/download) (verificado con `dotnet --version` → `10.0.302`).
- [Node.js 24.x](https://nodejs.org/) y npm 11.x (verificado con `node -v` → `v24.13.1`, `npm -v` → `11.8.0`).
- Angular CLI se usa vía `npx`/`npm run`; no requiere instalación global.

### Restaurar dependencias

```bash
# Backend
dotnet restore Centinela.slnx

# Frontend
cd web/centinela-web
npm install
```

### Iniciar la API (puerto 5299)

Desde la raíz del repositorio, **sin necesidad de establecer `ASPNETCORE_URLS` manualmente** — el puerto está fijado en `src/Centinela.Api/Properties/launchSettings.json`:

```bash
dotnet run --project src/Centinela.Api
```

La API queda disponible en `http://localhost:5299`.

### Iniciar el Chat Web (puerto 4200)

En otra terminal, **después de que la API esté arriba** (el frontend depende de la API para responder):

```bash
cd web/centinela-web
npm start
```

El Chat Web queda disponible en `http://localhost:4200`.

### URLs y verificación

- Chat Web: `http://localhost:4200`
- Health check de la API: `http://localhost:5299/health`

### Ejemplos de consultas para probar en el Chat Web

- `¿Cuánto cuesta la Lámpara Aurora?` — precio, con fuente citada.
- `¿Hay disponibilidad de la Lámpara Aurora?` — disponibilidad.
- `¿Qué características tiene la Lámpara Aurora?` — características.
- `¿Cuál es la política de devoluciones?` — política local.
- `Necesito algo para la cocina con presupuesto de 150.000` — recomendación con candidatos del catálogo.
- `Recomiéndame un escritorio gamer con presupuesto de 100.000` — sin coincidencias en el catálogo local: escala a atención humana, sin inventar productos.
- `¿Tienen escritorios gamer disponibles?` — producto inexistente: escala a atención humana.
- `Estoy muy molesto, el producto llegó dañado y es un reclamo` — queja: escala a atención humana con resumen para el humano.

### Ejecutar las pruebas backend

```bash
dotnet test Centinela.slnx --configuration Release
```

### Ejecutar las pruebas frontend

```bash
cd web/centinela-web
npm test -- --watch=false
```

### Nota sobre la IA usada en esta fase

`FakeModelGateway` **no es Claude, no es Microsoft Foundry y no es ningún modelo de IA real**. Es una implementación local y determinista que aplica plantillas fijas sobre hechos extraídos del catálogo/políticas locales, sin llamadas de red ni tokens. La selección de un proveedor de IA real requiere aprobación humana explícita previa (ver [ADR-003](docs/architecture/adr/ADR-003-model-gateway.md)).

### Nota sobre Azure

Esta fase **no usa Azure**: no se ejecutó ningún comando `az`, no se creó ni modificó ningún recurso de Azure, y no se tocó ningún archivo Bicep. Toda la persistencia es en memoria o en archivos JSON locales versionados como datos ficticios.

## Gobierno del proyecto

- [`CLAUDE.md`](CLAUDE.md) — Instrucciones para Claude Code.
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — Flujo de contribución y ramas.
- [`SECURITY.md`](SECURITY.md) — Política de seguridad.
- [`docs/governance/`](docs/governance/) — Estrategia de ramas, convenciones y Definition of Done.
- [`docs/architecture/adr/`](docs/architecture/adr/) — Registro de decisiones de arquitectura.

## Desarrollo

Este repositorio se desarrolla exclusivamente mediante **Claude Code**, con evidencia registrada a través del proxy asignado. Ver [`docs/evidence/`](docs/evidence/) para los reportes de cada fase.

## Restricciones del proyecto

- Ambiente inicial: `dev`.
- Canal del MVP: Chat Web (único).
- Presupuesto máximo: USD 50.
- Región Azure principal: East US 2. Alternativa: Central US.
- Todos los datos son ficticios.

## Licencia

Pendiente de decisión del desarrollador.
