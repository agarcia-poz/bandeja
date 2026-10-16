# Bandeja

App de la escuela de pádel: pagos y bonos con emails automáticos, registro de frecuencia cardíaca con pulsómetros Bluetooth, tests de condición física, interpretación con IA y un portal para cada alumno.

- **App:** https://agarcia-poz.github.io/bandeja/
- **Modo demostración** (datos de ejemplo, no toca la base de datos): https://agarcia-poz.github.io/bandeja/#demo

## Piezas

| Pieza | Dónde | Qué hace |
|---|---|---|
| `index.html` | GitHub Pages | Toda la interfaz (escuela y portal del alumno) |
| `supabase/migrations/` | Supabase (proyecto `bandeja`, París) | Tablas, seguridad por filas y comparativa anónima |
| `supabase/functions/activar-acceso` | Supabase Edge Functions | El alumno activa su cuenta con código + email |
| `supabase/functions/enviar-emails` | Supabase Edge Functions | Envía la cola de emails a través de Gmail |
| `supabase/functions/interpretar-fc` | Supabase Edge Functions | Redacta con IA la interpretación de los datos (borrador que revisa el entrenador) |
| `apps-script/Code.gs` | Google Apps Script en escuelapadelag@gmail.com | Envía los emails desde la Gmail de la escuela |
| `.github/workflows/mantener-activo.yml` | GitHub Actions | Consulta mínima cada 3 días para que Supabase no pause el proyecto |

## Secretos de las funciones (Supabase → Edge Functions → Secrets)

- `APPS_SCRIPT_URL`: URL `/exec` de la implementación del script de Gmail.
- `APPS_SCRIPT_SECRETO`: la misma clave guardada en las propiedades del script.
- `ANTHROPIC_API_KEY`: clave de la API de Claude para las interpretaciones.
- `ANTHROPIC_MODEL` (opcional): modelo a usar; por defecto `claude-sonnet-5-5`.

## Pulsómetros

Web Bluetooth con el servicio estándar *Heart Rate*. Funciona en Chrome o Edge (Android, Windows, macOS, ChromeOS). No funciona en Safari de iPhone/iPad; allí se puede usar el navegador Bluefy.

## Cálculos (los de la hoja GESTIÓN ESCUELA)

- FC máxima teórica: 220 − edad.
- Zonas: Z1 50–60 %, Z2 60–70 %, Z3 70–80 %, Z4 80–90 %, Z5 90–100 %.
- Índice de recuperación: %FC máxima − %FC media.
- eTRIMP (Edwards): minutos en Z1 × 1 + … + Z5 × 5.
- Calorías: ecuación de Keytel et al. (2005).

## Protección de datos

La frecuencia cardíaca es un dato de salud (art. 9 RGPD): la ficha recoge el consentimiento (y el tutor en menores). Cada alumno solo puede leer sus propios datos; las comparativas con el grupo se calculan sobre datos anónimos. A la IA no se le envía el nombre del alumno.
