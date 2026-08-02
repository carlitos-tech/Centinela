# CLAUDE.md — web/

Esta carpeta contendrá el frontend de Centinela: el canal **Chat Web**, único canal autorizado para el MVP.

## Estado actual

**Sin código funcional.** Esta carpeta no debe contener proyectos Angular, `package.json` funcional, ni implementaciones hasta que la fase correspondiente del plan sea explícitamente autorizada.

## Reglas cuando se autorice el desarrollo

- El único canal del MVP es Chat Web. No se agregan otros canales (WhatsApp, correo, voz, etc.) sin autorización explícita y una fase dedicada.
- El frontend consume la API del backend a través de contratos definidos; no contiene lógica de negocio propia.
- No se incrustan claves de API, tokens ni secretos en el código cliente.
- No se procesan ni muestran datos reales de ninguna empresa o persona — solo datos ficticios de NovaCasa S.A.S.
- Toda funcionalidad nueva incluye pruebas significativas donde aplique.
