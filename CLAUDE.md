# Bandeja · contexto para Claude Code

App web de la **Escuela de Pádel AG** (Úbeda) de Andrés García Pozas. Sustituye a su antigua app de AppSheet y a las hojas «Gestión de pagos» y «Gestión escuela». Habla siempre en **español de España**. Andrés no es programador: explica los cambios en lenguaje llano y dile qué ha cambiado para él, no el código.

## Restricciones
- **Coste cero.** Nada de servicios de pago (por eso la IA usa Groq y Gemini en su plan gratuito, y no la API de Anthropic).
- **Claves y secretos nunca en el repositorio.** Van en la tabla `config_privada` de Supabase, que solo leen las funciones del servidor.
- Antes de un cambio destructivo en la base de datos (borrar tablas o columnas, mover extensiones), pide confirmación.

## Piezas
| Pieza | Dónde |
|---|---|
| `index.html` | Toda la app en un solo archivo (Tailwind por CDN, Chart.js 4.4.1, supabase-js 2.45.4). Se publica en GitHub Pages: https://agarcia-poz.github.io/bandeja/ |
| `supabase/migrations/` | Esquema, seguridad por filas y funciones SQL. Proyecto Supabase **bandeja**, ref `kbqlnomchinlshaxccpo` (París, organización «Escuela de pádel AG») |
| `supabase/functions/` | Funciones del servidor: `activar-acceso`, `enviar-emails`, `interpretar` (IA: Groq `openai/gpt-oss-120b` y, si falla, Gemini), `automatico` (pg_cron cada 10 min: cobra la clase al terminar y envía el aviso de pago 1 h antes). Todas con `verify_jwt` desactivado: comprueban ellas el permiso (administrador o cabecera `x-cron-secret` = `CRON_TAREAS`). |
| `apps-script/Code.gs` | Relé de Gmail en la cuenta escuelapadelag@gmail.com (secreto `SECRETO` en sus propiedades = `APPS_SCRIPT_SECRETO` de `config_privada`) |
| `.github/workflows/mantener-activo.yml` | Consulta cada 3 días para que Supabase no pause el proyecto |

Administrador: escuelapadelag@gmail.com (tabla `admins`). Clave pública de Supabase y URL: están en `index.html` (`window.BANDEJA`).

## Cómo funciona la app (resumen)
- **Modo demostración**: sin configuración o con `#demo` en la URL, usa datos de ejemplo en `localStorage` (`bandeja-demo-v3`). Es la forma de probar sin tocar datos reales.
- **Alumnado**: fijos (se les cobra cada clase aunque falten, salvo que les cubra un relevo) y relevos (solo si vienen). Saldo = pagado + ajustes − clases cobradas. Desde el 27-10-2026 la clase se cobra sola al terminar (`ajustes.auto_desde`); pasar lista solo corrige.
- **Pagos** con cantidad (p. ej. 2 clases sueltas), precios editables en *Pagos → Precios*, gastos y balance mensual. Email de agradecimiento al registrar un pago.
- **Clases**: calendario por grupo con clases movidas, anuladas y extra (`grupos.calendario`). **Diseño de sesiones** (`sesiones.plan`, jsonb) con el formato de su hoja de sesión: fases, tareas con minutos, físico/competición/variante/objetivo/puntuación, objetivos (min > 90 % FC máx. y RPE), versiones por pista, impresión A4 apaisada y «Aplicar también a» otras clases (copias enlazadas con `origen`).
- **Pulsómetros** Bluetooth (Web Bluetooth; en iPhone/iPad solo con Bluefy), pantalla completa por zonas, resumen de sesión por email. FC máx. = 220 − edad; eTRIMP de Edwards; calorías de Keytel.
- **Marcador**: partidos (sets, tie-break, punto de oro o ventajas, orden de saque, quién resta el oro) y juegos tácticos (por defecto 2 rondas a 15 puntos, una pareja saca toda la ronda, gana el mejor balance). Punto doble ×2 (con 30/40 en contra pasa a ventaja/40; si la pierde, 40-40 y punto de oro). Estadísticas por jugador y pareja, comparadas con grupo y escuela (`comparativa()` devuelve datos anónimos).
- **Portal del alumno**: inicio con conclusiones, bono, «Mi corazón» (gráfico configurable, carga semanal y relación agudo:crónico), «Mis partidos» por categorías, «Avisos» (emails y actividad). Entra con código PD-XXXXX + email.
- **Animaciones** con tokens `--ease-*`/`--t-*`; todo respeta `prefers-reduced-motion`.

## Forma de trabajar
- Edita `index.html` con cambios pequeños y precisos; es un archivo grande.
- Tras cambiar el JavaScript, comprueba la sintaxis extrayendo el bloque `<script>` principal y pasándolo por `node --check`.
- Prueba en modo demostración (`index.html#demo`), también a 390 px de ancho (sin scroll horizontal) y con «reducir movimiento».
- Cambios de base de datos: crea un archivo nuevo en `supabase/migrations/` (fecha y nombre descriptivo) y aplícalo con el MCP de Supabase.
- Commits en español, con autor Andrés García Pozas <andresgarcia@fundacionsafa.es>. Publicar = `git push` a `main` (GitHub Pages se actualiza solo en uno o dos minutos).
- Actualiza `README.md` cuando cambie algo que Andrés deba saber.

## Pendiente o en estudio
- Dominio propio para la web (GitHub Pages lo admite gratis; falta que Andrés elija y compre el dominio). Al cambiarlo hay que actualizar `APP_URL` y las etiquetas `og:` de `index.html`, añadir el archivo `CNAME` y la *Site URL* / *Redirect URLs* de Supabase Auth.
- La tabla `tests_fisicos` ya no se usa (no se ha borrado).
