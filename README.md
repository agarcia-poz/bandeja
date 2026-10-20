# Bandeja

App de la escuela de pádel: pagos y bonos con emails automáticos, pulsómetros Bluetooth en directo (con pantalla completa por zonas), marcador de partidos con winners y errores no forzados, comparativas con el grupo y la escuela, informes redactados con Gemini y un portal para cada alumno. Todo con servicios gratuitos.

- **App:** https://agarcia-poz.github.io/bandeja/
- **Modo demostración** (datos de ejemplo, no toca la base de datos): https://agarcia-poz.github.io/bandeja/#demo

## Piezas

| Pieza | Dónde | Qué hace |
|---|---|---|
| `index.html` | GitHub Pages | Toda la interfaz (escuela y portal del alumno) |
| `supabase/migrations/` | Supabase (proyecto `bandeja`, París) | Tablas, seguridad por filas y comparativa anónima |
| `supabase/functions/activar-acceso` | Supabase Edge Functions | El alumno activa su cuenta con código + email |
| `supabase/functions/enviar-emails` | Supabase Edge Functions | Envía la cola de emails a través de Gmail |
| `supabase/functions/interpretar` | Supabase Edge Functions | Informes del alumno y lectura táctica del partido con IA gratuita (Groq y, si falla, Gemini), sin datos personales |
| `apps-script/Code.gs` | Google Apps Script en escuelapadelag@gmail.com | Envía los emails desde la Gmail de la escuela |
| `.github/workflows/mantener-activo.yml` | GitHub Actions | Consulta mínima cada 3 días para que Supabase no pause el proyecto |

## Configuración privada

La URL del script de Gmail, su secreto y las claves de IA (`GROQ_API_KEY`, `GEMINI_API_KEY`; opcionalmente `GROQ_MODEL`, `GEMINI_MODEL` e `IA_ORDEN`) están en la tabla `config_privada` de Supabase, que solo leen las funciones del servidor. Nunca en este repositorio.

## Pulsómetros

Web Bluetooth con el servicio estándar *Heart Rate*. Funciona en Chrome o Edge (Android, Windows, macOS, ChromeOS). No funciona en Safari de iPhone/iPad; allí se puede usar el navegador Bluefy.

## Bonos, fijos y relevos

- **Fijo del grupo:** se le cobra cada clase con lista pasada, aunque falte, salvo que le cubra un relevo.
- **Relevo:** pertenece a un grupo, pero solo se le cobra la clase cuando viene. Cualquier alumno puede añadirse a la lista de otro grupo.
- **Ajustes:** desde la ficha del alumno se suman o restan clases con un motivo (por ejemplo, una clase que no hay que cobrarle).
- Saldo = clases pagadas + ajustes − clases cobradas.

## Gastos y balance

En *Pagos* hay tres pestañas: cobros, gastos (por categoría) y balance mensual con ingresos, gastos, resultado, margen y clases impartidas.

## Partidos (hoja ANÁLISIS ESTADÍSTICO)

- Cada punto se registra como winner o error no forzado de un jugador con su golpe (S, D, R, PD, PR, CP, VD, VR, B, RMP, RML), o como punto sin winner ni error.
- El marcador lleva sets, juegos, tie-break a 6-6, punto de oro o ventajas, saque y bolas de break.
- % ENF = errores del jugador / puntos perdidos por su pareja. % WIN = winners del jugador / puntos ganados por su pareja.
- Índice win = media de % puntos de oro ganados y % roturas conseguidas.

## Cálculos de pulsómetro (hoja GESTIÓN ESCUELA)

- FC máxima teórica: 220 − edad.
- Zonas: Z1 50–60 %, Z2 60–70 %, Z3 70–80 %, Z4 80–90 %, Z5 90–100 %.
- Índice de recuperación: %FC máxima − %FC media.
- eTRIMP (Edwards): minutos en Z1 × 1 + … + Z5 × 5.
- Calorías: ecuación de Keytel et al. (2005).

## Protección de datos

La frecuencia cardíaca es un dato de salud (art. 9 RGPD): la ficha recoge el consentimiento (y el tutor en menores). Cada alumno solo puede leer sus propios datos; las comparativas con el grupo se calculan sobre datos anónimos. Para los informes con Gemini solo se envían porcentajes y medias, sin nombre, edad ni contacto. En el plan gratuito de la API de Gemini, Google puede usar lo que se le envía para mejorar sus productos.
