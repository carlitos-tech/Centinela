# Estimación de costos — Infraestructura DEV (Fase 03)

Estimación de referencia, no una factura. Los precios de Azure varían por región, divisa,
promociones vigentes y consumo real; esta tabla usa los precios de lista consultados en las
fuentes oficiales citadas y **no** sustituye a la Calculadora de precios de Azure ni a Cost
Management una vez exista una suscripción real con consumo.

- **Fecha de consulta:** 2026-08-02.
- **Región de referencia:** East US 2 (principal). Central US (alterna) no se cotiza aquí; se
  documenta como opción de conmutación manual si East US 2 no tuviera disponibilidad de algún SKU.
- **Supuestos:** carga de desarrollo/demo (tráfico bajo, sin escalado horizontal, sin alta
  disponibilidad, sin failover geográfico, retención de logs de 30 días, sin componentes de IA
  habilitados).

## Detalle por recurso

| Recurso | SKU | Estimado mensual (USD) | Fuente / nota |
|---|---|---|---|
| App Service Plan (Linux) + Web App | B1 Basic | ~13.14 | Precio de lista B1 Linux citado en múltiples referencias públicas de Microsoft Q&A y guías de precios de terceros; confirmar en el momento del despliegue real con la [página oficial de precios de App Service](https://azure.microsoft.com/pricing/details/app-service/linux/). |
| Azure SQL Database | Basic (5 DTU, 2 GB) | ~5.00 (rango observado 5–20 según región/uptime) | Precio de lista Basic ≈ $0.0068/hora × 730 h ≈ $4.96–5.00; confirmar en la [página oficial de precios de Azure SQL Database](https://azure.microsoft.com/pricing/details/azure-sql-database/single/). |
| Storage Account | StorageV2, Standard_LRS | ~1–3 | Costo dominado por GB almacenados y transacciones; para un catálogo/tráfico de demo (unos pocos GB), el costo de almacenamiento y operaciones es marginal. Ver [precios de Azure Storage](https://azure.microsoft.com/pricing/details/storage/blobs/). |
| Log Analytics Workspace + Application Insights | PerGB2018 | ~0–3 | Primeros 5 GB de ingesta por mes sin costo por suscripción; una carga de demo normalmente no supera ese umbral. Application Insights se factura sobre el mismo volumen de ingesta (sin cargo adicional independiente). Ver [precios de Azure Monitor](https://azure.microsoft.com/pricing/details/monitor/). |
| Key Vault | Standard | <1 | Facturado por operación (~$0.03 por 10.000 operaciones); volumen de demo es marginal. Ver [precios de Key Vault](https://azure.microsoft.com/pricing/details/key-vault/). |
| Resource Group | — | 0 | El Resource Group en sí no tiene costo. |

## Total estimado

**Rango estimado: ~USD 20 – 30/mes**, con un techo conservador de ~USD 35/mes si Log Analytics
supera el nivel gratuito o el tráfico de demo es mayor al supuesto.

- **Objetivo de baseline DEV:** ≤ USD 40/mes. **Cumple** con el rango estimado.
- **Reserva mínima:** USD 10/mes por debajo del límite absoluto, para variaciones de consumo no
  previstas (ingesta de logs, transacciones de Storage, egress).
- **Límite absoluto del proyecto:** USD 50/mes (ver `CLAUDE.md`, sección 5). Si una revisión futura
  de esta arquitectura proyectara superar este límite, el diseño debe bloquearse y revisarse antes
  de cualquier despliegue real.

## Componentes deliberadamente excluidos de esta estimación

- **Microsoft Foundry** y **Azure AI Search**: `enableFoundry = false`, `enableAiSearch = false`.
  No se modela ningún costo porque no se declara ningún recurso activo para ellos en esta fase.
- **Alta disponibilidad, escalado, VNet/Private Endpoint, geo-redundancia**: fuera de alcance del
  presupuesto de un walking skeleton de hackathon; quedarían sujetos a una fase y aprobación
  separadas si el proyecto avanza a un entorno de mayor exigencia.

## Advertencia de precisión

Estas cifras son órdenes de magnitud basados en precios de lista públicos a la fecha de consulta,
no cotizaciones contractuales. Antes de cualquier despliegue real (Fase 04 o posterior, sujeta a
aprobación humana explícita), se debe volver a confirmar el precio vigente con la Calculadora de
precios de Azure para la suscripción y región exactas que se vayan a usar.
