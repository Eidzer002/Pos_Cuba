# AGENTS.md — POS Cuba
# Instrucciones para el agente de codificación (Antigravity / cualquier agente compatible)
# Este archivo se lee automáticamente al iniciar cada sesión.

## Identidad del proyecto

**POS Cuba** es un sistema de punto de venta para negocios de reventa de servicios en Cuba.
Es el port a Flutter de una PWA existente (index.html + index.js en la raíz).
No es un proyecto nuevo — es una migración. Respetá la lógica de negocio de la PWA original.

## Stack tecnológico obligatorio

```
Flutter 3.x (sin Firebase — Firebase está bloqueado en Cuba)
Supabase (auth + base de datos en la nube)
PowerSync v1.17+ (sincronización offline-first, cliente Rust por defecto)
Riverpod 3.x (state management, SOLO con @riverpod code generation)
GoRouter 14.x (navegación declarativa con guards)
```

## Documentación de referencia

Antes de implementar cualquier feature, consultá estos archivos:

- **SRS_POSCuba** — Requisitos funcionales completos. Define qué debe hacer cada pantalla.
- **TECH_SPEC_POSCuba** — Especificación técnica. Define cómo debe construirse. Incluye los 6 bugs conocidos de la PWA que deben corregirse en Flutter.
- **`lib/data/local/powersync_schema.dart`** — Schema completo de la base de datos. Fuente de verdad para todos los campos.

## Reglas de arquitectura (OBLIGATORIAS)

### Capas — dónde va cada cosa
```
lib/data/repositories/   → TODO acceso a la base de datos. Sin excepciones.
lib/providers/           → Estado de la app con @riverpod
lib/services/            → Servicios singleton (PowerSync, LicenseService)
lib/presentation/        → Widgets y pantallas únicamente
lib/core/                → Utils, constantes, tema
```

**Prohibido:**
- Llamar `db.execute()` o `db.watch()` desde providers, services o screens
- Llamar `Supabase.instance` fuera de `lib/data/remote/` o `lib/services/`
- Lógica de negocio en widgets

### Base de datos
- PowerSync `db.watch()` retorna `Stream<ResultSet>` — nunca `Future`
- Operaciones que modifican múltiples tablas: **siempre** `writeTransaction`
- IDs nuevos: `const Uuid().v4()`
- Fechas: `DateTime.now().toIso8601String()`
- `bool` en SQLite: `(row['campo'] as int) == 1`
- `DateTime` desde SQLite: `DateTime.parse(row['campo'] as String)`
- Campos nullable: `row['campo'] as String?`
- **Siempre** filtrar por `business_id` en cada query

### Patrones de código
- `try/catch` con `debugPrint('NombreClase.metodo: $e\n$stack')` y `rethrow` en todos los repositorios
- Modelos Dart: constructor `const`, `factory fromRow(ResultRow)`, `copyWith()`
- Providers: `@riverpod` con code generation. **Sin** `StateProvider` ni `StateNotifierProvider` (legacy)
- Widgets: `const` constructor siempre que sea posible

## Reglas de negocio críticas

### Moneda
- El símbolo de moneda **NUNCA** se hardcodea como `$`, `CUP` o `MXN`
- Siempre viene de `business.currencySymbol` del `currentBusinessProvider`
- Esto aplica en TODAS las pantallas sin excepción (FIX BUG-04 del TECH_SPEC)

### Seguridad del PIN
- El PIN del trabajador se hashea con **SHA-256** antes de guardarse (FIX BUG-01)
- Usar `SecurityUtils.hashPin()` — nunca escribir el hash manualmente
- `authenticateByPin()` busca por hash. **NUNCA** comparar texto plano
- El estado de sesión del trabajador es **IN-MEMORY** — no se persiste en disco (FIX BUG-02)

### Ventas
- `processSale()` usa un único `writeTransaction` que cubre:
  verificación de stock → descuento de stock → inserción venta → inserción items → log stock_movements
- Si falla cualquier paso, todo se revierte automáticamente
- El `product_name` en `sale_items` se guarda como snapshot para el historial

### Caja
- Solo puede haber **una** `cash_session` con `status='open'` por negocio a la vez (FIX BUG-03)
- La verificación de sesión abierta debe hacerse **dentro** del `writeTransaction` de apertura

## Skills disponibles

Las skills en `.agent/skills/` definen patrones de código específicos para este proyecto.
Cuando la tarea involucra alguno de estos dominios, **leer el skill antes de escribir código**:

| Skill | Cuándo usarlo |
|-------|--------------|
| `powersync-queries/SKILL.md` | Cualquier `db.watch()` o query con PowerSync |
| `sale-transaction/SKILL.md` | `processSale()`, `cancelSale()`, writeTransaction |
| `riverpod-3-patterns/SKILL.md` | Cualquier provider nuevo o modificado |
| `license-system/SKILL.md` | `LicenseService`, pantallas de licencia |
| `navigation-guards/SKILL.md` | Guards del router, redirecciones |
| `security-pin-hash/SKILL.md` | PIN, hashing, WorkerSession |
| `dashboard-reports-logic/SKILL.md` | KPIs, `calculateWorkerPay()`, fechas del dashboard |
| `supabase-edge-functions/SKILL.md` | Edge Functions TypeScript/Deno |
| `csv-export-import/SKILL.md` | Export de reportes y backup, import de productos |
| `git-commits-pos/SKILL.md` | Formato de commits del proyecto |

## Rules del proyecto

Las rules en `.agent/rules/` siempre están activas. Definen:
- `01-architecture.md` — Estructura de carpetas y separación de capas
- `02-database.md` — Patrones de acceso a datos y PowerSync
- `03-security.md` — PIN, hashing, tokens, flutter_secure_storage
- `04-code-quality.md` — Estilo de código, Riverpod 3.x, dart analyze
- `05-git-deploy.md` — Conventional commits, .gitignore, build
- `06-business-logic.md` — Lógica de negocio: ventas, caja, comisiones, licencias

## Bugs de la PWA a corregir en Flutter

| Bug | Descripción | Fix |
|-----|-------------|-----|
| BUG-01 | PIN guardado en texto plano | SHA-256 con `SecurityUtils.hashPin()` |
| BUG-02 | Rol del worker en sessionStorage | Estado IN-MEMORY en Riverpod |
| BUG-03 | Posible doble caja abierta | UNIQUE constraint + verificación en writeTransaction |
| BUG-04 | Moneda hardcodeada | Campo `currency_symbol` editable en settings |
| BUG-05 | N/A en Flutter | Era bug específico de HTML/JS |
| BUG-06 | N/A en Flutter | Era bug específico de HTML/JS |

## Idioma

**Todos los textos visibles al usuario en español.**
Esto incluye: labels, botones, mensajes de error, snackbars, placeholders, tooltips.
Los nombres de variables, clases y métodos van en inglés (convención Dart).

## Comandos útiles

```bash
# Correr en desarrollo
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=POWERSYNC_URL=...

# Regenerar providers de Riverpod (después de cambiar cualquier @riverpod)
dart run build_runner build --delete-conflicting-outputs

# Verificar que compila sin errores
flutter analyze

# Build de release
flutter build apk --release --obfuscate --split-debug-info=build/debug-info --dart-define=...
```
