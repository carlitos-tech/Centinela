# Reporte de evidencia — Fase 01: Gobierno del repositorio

## Metadatos

- **Fecha/hora (America/Bogota):** 2026-08-02, 14:28 (UTC-5)
- **Modelo y esfuerzo usados:** Sonnet 5, esfuerzo alto (configurado antes del inicio de la Fase 01)
- **Rama de trabajo:** `chore/phase-01-repository-governance` (creada desde `develop`)
- **Remoto configurado:** `https://github.com/carlitos-tech/Centinela.git`
- **Issue de la fase:** [#1 — Phase 01: Repository governance](https://github.com/carlitos-tech/Centinela/issues/1)
- **Pull Request de la fase:** [#2](https://github.com/carlitos-tech/Centinela/pull/2) — rama de trabajo `chore/phase-01-repository-governance` → rama base `develop`. **Estado: abierto, sin fusionar.**

## Resultado

**PASS CON OBSERVACIONES**, en proceso de corrección tras revisión automática del Pull Request. Ver sección "Ciclo de corrección post-revisión" y "Observaciones y decisiones registradas". El resultado definitivo de la fase queda condicionado a que el workflow de gobierno se ejecute en verde sobre el commit corrector y a la aprobación humana explícita del Pull Request.

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

### Planeación (agregado durante el ciclo de corrección)
- `docs/planning/implementation-plan.md` — plan de implementación saneado, con las Fases 00 a 10 en orden secuencial, compuertas de aprobación, restricciones transversales y presupuesto/región/retención/tiempo de respuesta objetivo. No reproduce nombres de proyecto obsoletos ni información privada de `docs/00-contexto-inicial/` (carpeta no versionada).

### Ya existentes de la Fase 00 (no modificados en esta fase, salvo lo indicado)
- `README.md`, `.gitignore` (creados en el bootstrap de esta misma fase)
- `docs/evidence/preflight-report.md`
- `docs/evidence/evidencia funcionamiento proxy.png`

## Commits realizados

1. `chore: bootstrap repository` — en `main` (README.md, .gitignore)
2. `chore: establish repository governance` — en `chore/phase-01-repository-governance` (todos los archivos listados arriba)
3. `fix: harden Phase 01 governance validation` — SHA `179fc651a46c14d8e88f446a2ed9360819088dc8` — en `chore/phase-01-repository-governance` (corrección del hallazgo de revisión de xargs; ver "Ciclo de corrección post-revisión").
4. `fix: remove self-matching example from Phase 01 evidence report` — SHA `1869e02` — en `chore/phase-01-repository-governance` (corrige un ejemplo autorreferente detectado por la propia ejecución del workflow sobre el commit anterior; ver "Segundo hallazgo").
5. `fix: remove remaining self-matching path examples from evidence report` — en `chore/phase-01-repository-governance` (la narrativa del commit anterior reintrodujo la misma cadena de ejemplo en prosa; se reescribe sin cadena coincidente). SHA pendiente de registrar tras el push.

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
- Validaciones incluidas: existencia y no vacuidad de archivos de gobierno requeridos; ausencia de `.claude/settings.local.json` versionado; ausencia de archivos `.env` con valores; ausencia de proyectos funcionales prematuros (`.csproj`, `.sln`, `angular.json`, `.bicep`, `.sql` en `database/`); escaneo de secretos/credenciales conocidos, rutas locales completas, correos electrónicos y GUIDs (posibles Tenant/Subscription ID) sin enmascarar.
- No es un workflow de CI/CD de aplicación: no compila, no prueba ni despliega código funcional (no existe código funcional en esta fase).
- **Nota:** el workflow **no** contiene ninguna validación específica de nombre de empresa real (ni en texto plano ni codificada) — ver "Ciclo de corrección post-revisión" para el detalle de por qué se eliminó y cómo se sustituyó por validaciones genéricas.

## Ciclo de corrección post-revisión

Tras la apertura del PR #2, la revisión automática (`chatgpt-codex-connector[bot]`, comentario en `.github/workflows/governance.yml:132`, sobre el commit `c477952ba0b7fb3f48d53af50a277407cf180044`) identificó un hallazgo de severidad P2 y se ejecutó un ciclo de corrección sobre la misma rama, sin crear una rama nueva y sin fusionar el PR.

### Hallazgo

El paso "Escaneo de secretos y datos sensibles conocidos" usaba el patrón `git ls-files | xargs grep -lIE "$pattern" 2>/dev/null`. `xargs`, por defecto, separa los nombres de archivo recibidos por espacios en blanco, por lo que un archivo legítimo y ya versionado con espacio en el nombre — `docs/evidence/evidencia funcionamiento proxy.png` — se dividía en múltiples argumentos incorrectos. Además, `2>/dev/null` ocultaba cualquier error real de `grep` derivado de esa división, de modo que un archivo podía quedar sin analizar sin que el workflow lo reportara como fallo.

### Corrección implementada

1. Los pasos que listan archivos por patrón (`.env`, proyectos funcionales prematuros) ahora usan `git ls-files -z` (salida delimitada por NUL) en lugar de separación por espacios en blanco.
2. El paso de escaneo de datos sensibles se reescribió para usar `git grep -zIlE` directamente sobre el contenido versionado, que no depende de dividir una lista de rutas por espacios y por tanto no puede omitir un archivo por tener espacios en el nombre.
3. Los códigos de salida de `git grep` se interpretan explícitamente: `0` = coincidencia real (dato sensible detectado, falla el job), `1` = sin coincidencias (resultado normal), `>1` = fallo real de la herramienta — este último ya **no se oculta** y aborta el job con código de salida distinto de cero, en lugar de tratarse como "sin resultados".
4. Se **eliminó por completo** el patrón (antes codificado en Base64 dentro del propio workflow) que detectaba el nombre de una organización real. No se sustituyó por ninguna otra codificación reversible. La detección de nombres de empresas reales queda como una validación **local y manual**, ejecutada por el desarrollador antes de cada commit, cuyo patrón nunca se escribe en ningún archivo versionado del repositorio. El workflow permanente solo retiene validaciones genéricas que no requieren versionar ningún nombre identificable: secretos/credenciales conocidos, rutas locales completas, correos electrónicos (nuevo) y GUIDs sin enmascarar.
5. Se actualizaron el Issue #1 (referencia a organización real reemplazada por lenguaje genérico; enlaces rotos hacia `main` reemplazados por referencia temporal al PR #2; checklist de Definition of Done ajustado al estado real) y el cuerpo del PR #2 (`Closes #1` → `Refs #1`; ítem de workflow en verde permanece sin marcar hasta confirmación; se mantiene y refuerza el lenguaje de "no fusionar sin aprobación humana explícita").

### Commit corrector

- **Commit 1:** `fix: harden Phase 01 governance validation` — SHA `179fc651a46c14d8e88f446a2ed9360819088dc8`.
- **Rama:** `chore/phase-01-repository-governance` (misma rama, sin crear una nueva).

### Segundo hallazgo: autorreferencia en el propio reporte de evidencia

La ejecución del workflow sobre el commit `179fc65` **falló** (no por un defecto de lógica del escaneo, sino por un dato real detectado correctamente): el paso "Escaneo de secretos y datos sensibles conocidos" marcó `docs/evidence/phase-01-governance-report.md` porque ese mismo reporte contenía, como texto de ejemplo dentro de la sección "Validación local", el prefijo de ruta de perfil de usuario de Windows seguido de puntos suspensivos. Los puntos suspensivos caen dentro de la clase de caracteres del patrón de rutas locales, por lo que el ejemplo coincidía con su propio patrón de detección. Esto confirma que el escaneo corregido **sí detecta** coincidencias reales y no oculta el hallazgo — el comportamiento es el esperado, el problema estaba en el texto de ejemplo del reporte, no en la lógica de detección.

**Corrección:** se reescribió el ejemplo para describir el formato de ruta en prosa, sin incluir ninguna cadena que coincida con el patrón de detección. Se re-ejecutó la validación local completa tras el cambio, confirmando `0 coincidencias` en las cuatro categorías genéricas.

- **Commit 2:** `fix: remove self-matching example from Phase 01 evidence report` — SHA `1869e02` (complemento — corrige el ejemplo autorreferente en el reporte de evidencia detectado por la propia ejecución del workflow sobre el commit 1).
- **Commit 3:** `fix: remove remaining self-matching path examples from evidence report` (segundo complemento — la narrativa añadida en el commit 2 para describir el hallazgo reintrodujo, en prosa, la misma cadena de ejemplo que activaba el patrón; se reescribió en prosa sin cadena coincidente). SHA: _pendiente de registrar tras el push_.

### Resultado del workflow

| Commit | Conclusión | Detalle |
|---|---|---|
| `179fc65` (commit 1) | **failure** | Detección correcta de una autorreferencia en el propio reporte de evidencia (ver "Segundo hallazgo" arriba). No es un fallo del mecanismo de escaneo; confirma que el escaneo corregido detecta coincidencias reales sin ocultarlas. |
| `1869e02` (commit 2) | **failure** | El texto añadido para documentar el primer hallazgo volvió a citar literalmente la cadena de ejemplo que coincide con el patrón, dentro de la propia narrativa del hallazgo. Nuevamente, detección correcta del escaneo, no un fallo de su lógica. |
| commit 3 (segundo complemento) | _pendiente de registrar tras el push — se completa con la URL y la conclusión (`success`/`failure`) antes de considerar cerrado el ciclo de corrección_ | |

### Estado del comentario de revisión

- **Comentario:** [id `3700117477`](https://github.com/carlitos-tech/Centinela/pull/2#discussion_r3700117477), de `chatgpt-codex-connector[bot]`, sobre `.github/workflows/governance.yml:132`.
- **Estado:** _pendiente de respuesta y de marcar como resuelto — se actualiza una vez que el workflow se ejecute en verde sobre el commit 2._

## Validación local (equivalente al workflow, ejecutada durante el ciclo de corrección)

Ejecutada manualmente sobre el contenido versionado de la rama `chore/phase-01-repository-governance` mediante `git grep`, replicando exactamente la lógica del workflow corregido:

- Secretos/credenciales conocidos (tokens GitHub, AWS, Slack, llaves privadas): **0 coincidencias**.
- Rutas locales completas (formato de perfil de usuario de Windows o formato `/home/` de Unix): **0 coincidencias**.
- Correos electrónicos (patrón genérico, sin listar proveedores específicos): **0 coincidencias**.
- Identificadores tipo GUID (posibles Tenant ID / Subscription ID sin enmascarar): **0 coincidencias**.
- Nombre de organización real asociada al desarrollador (validación local, patrón no versionado en ningún archivo): **0 coincidencias** en texto plano ni codificado.
- Cadenas de conexión (`Server=...;Password=...`): **0 coincidencias**.
- `.claude/settings.local.json`: confirmado **no rastreado** por git.
- Archivos `.env` con valores: **0 encontrados**.
- Proyectos funcionales prematuros (`.csproj`, `.sln`, `angular.json`, `.bicep`, SQL funcional): **0 encontrados**.
- Sintaxis YAML de `.github/workflows/governance.yml`: **válida** (verificada con `yaml.safe_load`).
- Sintaxis Bash de los pasos del workflow: **válida** (verificada con `bash -n`).
- Archivos con espacios en el nombre (caso específico del hallazgo, `docs/evidence/evidencia funcionamiento proxy.png`): confirmado que el nuevo enfoque basado en `git grep`/`git ls-files -z` lo procesa correctamente, sin dividir la ruta.

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
