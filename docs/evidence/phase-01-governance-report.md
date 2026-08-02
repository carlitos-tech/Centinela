# Reporte de evidencia — Fase 01: Gobierno del repositorio

## Metadatos

- **Fecha/hora (America/Bogota):** 2026-08-02, 14:28 (UTC-5)
- **Modelo y esfuerzo usados:** Sonnet 5, esfuerzo alto (configurado antes del inicio de la Fase 01)
- **Rama de trabajo:** `chore/phase-01-repository-governance` (creada desde `develop`)
- **Remoto configurado:** `https://github.com/carlitos-tech/Centinela.git`
- **Issue de la fase:** [#1 — Phase 01: Repository governance](https://github.com/carlitos-tech/Centinela/issues/1)

## Resultado

**PASS CON OBSERVACIONES.** Ver sección "Observaciones y decisiones registradas".

## Bootstrap de Git

- Repositorio inicializado localmente con `main` como rama inicial.
- Identidad de Git configurada **solo local** (no global), usando el usuario público de GitHub y un correo `noreply` estándar de GitHub (no se muestra ni se versiona el correo personal del desarrollador).
- `.gitignore` creado antes del primer commit, excluyendo `.claude/settings.local.json`, archivos `.env` (salvo `.env.example`), certificados, `bin/`, `obj/`, `node_modules/`, `dist/`, `coverage/`, archivos temporales y configuraciones de IDE.
- Commit inicial `chore: bootstrap repository` (README.md + .gitignore) publicado en `main`.
- `main` confirmado como rama por defecto del repositorio.
- Rama `develop` creada desde `main` y publicada.
- Rama `chore/phase-01-repository-governance` creada desde `develop` para el resto del trabajo de esta fase.

## Archivos creados en esta fase

### Gobierno raíz
- `CLAUDE.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `.editorconfig`
- `.github/CODEOWNERS`
- `.github/pull_request_template.md`
- `.github/ISSUE_TEMPLATE/feature.yml`
- `.github/ISSUE_TEMPLATE/bug.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/workflows/governance.yml`

### CLAUDE.md por carpeta
- `src/CLAUDE.md`
- `web/CLAUDE.md`
- `infra/CLAUDE.md`
- `database/CLAUDE.md`

### Documentación de producto y arquitectura
- `docs/product/product-brief.md`
- `docs/product/mvp-scope.md`
- `docs/product/traceability-matrix.md`
- `docs/architecture/architecture-overview.md`
- `docs/architecture/decision-log.md`
- `docs/governance/branching-strategy.md`
- `docs/governance/commit-conventions.md`
- `docs/governance/definition-of-done.md`
- `docs/governance/security-rules.md`
- `docs/demo/demo-scorecard.md`
- `docs/demo/demo-script-initial.md`
- `docs/demo/contingency-plan.md`

### Architecture Decision Records
- `docs/architecture/adr/ADR-001-multiagent-architecture.md`
- `docs/architecture/adr/ADR-002-azure-cli-bicep.md`
- `docs/architecture/adr/ADR-003-model-gateway.md`

### Ya existentes de la Fase 00 (no modificados en esta fase, salvo lo indicado)
- `README.md`, `.gitignore` (creados en el bootstrap de esta misma fase)
- `docs/evidence/preflight-report.md`
- `docs/evidence/evidencia funcionamiento proxy.png`

## Commits realizados

1. `chore: bootstrap repository` — en `main` (README.md, .gitignore)
2. `chore: establish repository governance` — en `chore/phase-01-repository-governance` (todos los archivos listados arriba)

## Reglas de protección de ramas configuradas

Configuradas vía API de GitHub (`branches/{branch}/protection`) en `main` y `develop`:

- Pull Request requerido para integrar cambios.
- **0** aprobaciones obligatorias (`required_approving_review_count: 0`), acorde a equipo de un solo desarrollador.
- Revisión de CODEOWNERS **no** obligatoria (`require_code_owner_reviews: false`).
- Resolución de conversaciones requerida antes de merge (`required_conversation_resolution: true`).
- Force-push bloqueado (`allow_force_pushes: false`).
- Eliminación de rama bloqueada (`allow_deletions: false`).
- `enforce_admins: false` — el propietario (administrador del repositorio) no queda bloqueado por estas reglas y conserva la capacidad de crear ramas, publicar ramas, abrir Pull Requests y hacer merge de sus propios PRs.
- No se configuraron `required_status_checks` obligatorios inexistentes; el workflow de gobierno se ejecuta informativamente sobre los PRs.

Verificación: ambas llamadas a la API (`main` y `develop`) devolvieron `200 OK` con la configuración esperada.

## Funciones de seguridad de GitHub habilitadas

| Función | Estado |
|---------|--------|
| Secret scanning | Habilitado |
| Push protection (secret scanning) | Habilitado |
| Dependabot alerts (vulnerability-alerts) | Habilitado |
| Dependabot security updates (PRs automáticos de dependencias) | No habilitado — no se forzó, el repositorio aún no tiene manifiestos de dependencias reales |
| Bloqueo de force-push / eliminación en ramas protegidas | Habilitado (ver sección de protección de ramas) |

No se detectaron funciones solicitadas que estuvieran indisponibles por el plan de GitHub del repositorio (público, sin costo). Ninguna función fue simulada como activa sin verificación.

## Workflow de validación de gobierno

- Archivo: `.github/workflows/governance.yml`
- Disparadores: `pull_request` y `push` hacia `main` y `develop`.
- Acción oficial usada: `actions/checkout@v4.2.2` (versión fija, oficial).
- Validaciones incluidas: existencia y no vacuidad de archivos de gobierno requeridos; ausencia de `.claude/settings.local.json` versionado; ausencia de archivos `.env` con valores; ausencia de proyectos funcionales prematuros (`.csproj`, `.sln`, `angular.json`, `.bicep`, `.sql` en `database/`); escaneo de secretos conocidos, rutas locales completas, nombre de empresa real (patrón codificado en base64 dentro del workflow para no versionar el nombre real en texto plano) y GUIDs (posibles Tenant/Subscription ID) sin enmascarar.
- No es un workflow de CI/CD de aplicación: no compila, no prueba ni despliega código funcional (no existe código funcional en esta fase).

## Validación local (equivalente al workflow)

Ejecutada manualmente antes del commit final sobre todos los archivos nuevos (`.editorconfig`, `.github/`, `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`, `database/`, `docs/`, `infra/`, `src/`, `web/`):

- Secretos conocidos (tokens GitHub, AWS, Slack, llaves privadas): **0 coincidencias**.
- Rutas locales completas (`C:\Users\...`, `/home/...`): **0 coincidencias**.
- Nombre de empresa real (organización real asociada al desarrollador): **0 coincidencias** en texto plano. El patrón de detección usado por `.github/workflows/governance.yml` se codifica en base64 dentro del propio workflow y se decodifica solo en tiempo de ejecución, precisamente para que el nombre real no quede versionado como texto plano en ningún archivo del repositorio, ni siquiera dentro de la propia regla que lo detecta.
- Identificadores tipo GUID (posibles Tenant ID / Subscription ID sin enmascarar): **0 coincidencias**.
- Correos personales (gmail/outlook/hotmail/yahoo): **0 coincidencias**.
- `.claude/settings.local.json`: confirmado **no rastreado** por git.
- Archivos `.env` con valores: **0 encontrados**.
- Proyectos funcionales prematuros (`.csproj`, `.sln`, `angular.json`, `.bicep`, SQL funcional): **0 encontrados**.

## Confirmaciones

- No se incluyeron secretos, tokens, llaves ni cadenas de conexión.
- No se incluyó información real de ninguna empresa o persona (todo el contenido refiere a NovaCasa S.A.S., ficticia).
- No se tocaron recursos de Azure ni se registraron proveedores durante esta fase.
- No se implementó código funcional (.NET, Angular, SQL, Bicep) — las carpetas `src/`, `web/`, `infra/`, `database/` solo contienen `CLAUDE.md` con instrucciones.
- No se inició la Fase 02.
- No se realizó merge del Pull Request de esta fase.

## Observaciones y decisiones registradas

1. **Contradicción de nombres de ADR resuelta a favor de las instrucciones del usuario en el mensaje de autorización de la Fase 01.** El documento de planificación `docs/00-contexto-inicial/PLAN-CLAUDE/03-FASE-01-GOBIERNO-REPOSITORIO.md` especifica ADRs con otros nombres/contenidos (`ADR-001` "monolito modular", `ADR-002` "Azure CLI como Command Gateway", `ADR-003` "Claude, proxy y GitHub como flujo de implementación"). El mensaje de autorización explícita de la Fase 01 especificó en su lugar `ADR-001-multiagent-architecture.md`, `ADR-002-azure-cli-bicep.md` y `ADR-003-model-gateway.md`. Siguiendo la regla de resolución de contradicciones indicada por el usuario (prevalece el mensaje actual), se crearon los tres ADR con los nombres y contenidos indicados en el mensaje de autorización, y se deja registrada esta discrepancia aquí en lugar de sobrescribirla silenciosamente.
2. **`docs/00-contexto-inicial/` no fue versionado en esta fase.** Esta carpeta contiene la documentación de planificación original, que se refiere al proyecto por un nombre obsoleto ("Atenea CX Platform") y no forma parte del listado de archivos del alcance autorizado de la Fase 01. Se mantiene únicamente en el entorno local de trabajo; no se sube al repositorio público para evitar confusión con el nombre actual del proyecto (Centinela). Esta decisión queda registrada también en `docs/architecture/decision-log.md`.
3. **No se creó archivo `LICENSE`.** Queda pendiente como decisión del desarrollador, según lo indicado explícitamente en el mensaje de autorización de la Fase 01.
4. **Dependabot security updates (PRs automáticos)** no se activó explícitamente; solo se activaron las alertas de vulnerabilidad (Dependabot alerts). Al no existir todavía manifiestos de dependencias reales (sin código funcional), esta función no tiene efecto práctico aún y se deja para cuando exista código con dependencias.
5. Pendientes trasladados desde la Fase 00 (sin resolver en esta fase, por estar fuera de su alcance): permisos y cuotas de Azure, disponibilidad regional de servicios, disponibilidad de Microsoft Foundry, selección de modelos de IA/embeddings, estimación de costo detallada dentro del presupuesto de USD 50, confirmación operativa de exclusividad del canal Chat Web.

## Riesgos

- El escaneo de secretos del workflow de gobierno usa patrones conocidos (tokens de GitHub/AWS/Slack, llaves privadas) y detección de GUID; no sustituye un escáner de secretos dedicado de terceros, pero es consistente con las funciones nativas de GitHub (secret scanning) ya habilitadas a nivel de repositorio.
- `enforce_admins: false` significa que, técnicamente, el propietario podría hacer push directo a `main`/`develop` sin pasar por Pull Request. Esto es intencional (requisito explícito de no bloquear al propietario en un equipo de un solo desarrollador) pero depende de la disciplina del propio desarrollador para respetar el flujo de PR.

## Acciones pendientes del desarrollador

- Revisar y aprobar (o solicitar ajustes a) este reporte y el Pull Request de la Fase 01.
- Decidir la licencia del proyecto (o mantenerla pendiente indefinidamente).
- Autorizar explícitamente el inicio de la Fase 02 cuando corresponda.
- Resolver, en fases posteriores, los pendientes de Azure/Foundry/modelos listados en el punto 5 de "Observaciones y decisiones registradas".
