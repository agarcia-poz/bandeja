# Bandeja

App para la escuela de pádel: pagos y bonos con emails automáticos, registro de frecuencia cardíaca con pulsómetros Bluetooth, tests de condición física y un portal para cada alumno.

Este repositorio contiene el **prototipo navegable** (`index.html`, con datos de ejemplo guardados en el navegador) y el **esquema de base de datos** para la versión real (`supabase/migrations/`).

## Publicarlo en GitHub Pages

1. Crea un repositorio (por ejemplo `bandeja`) y sube estos archivos.
2. En *Settings → Pages*, elige *Deploy from a branch*, rama `main`, carpeta `/ (root)`.
3. En un minuto estará en `https://TU-USUARIO.github.io/bandeja/`.

GitHub Pages sirve por HTTPS, que es lo que exige el navegador para usar Bluetooth.

## Arquitectura propuesta para la versión real

| Pieza | Herramienta | Por qué |
|---|---|---|
| Interfaz | GitHub Pages (esta app) | Gratis, HTTPS, despliegue con cada `push` |
| Base de datos y acceso de alumnos | Supabase (plan gratuito) | Postgres con seguridad por filas: cada alumno solo puede leer sus datos |
| Emails de confirmación y aviso | Supabase Edge Function + Resend | Se disparan al registrar un pago o pasar lista |
| Interpretación con IA | Edge Function que llama a la API de Claude | La clave nunca está en el navegador; el entrenador revisa el texto antes de publicarlo |
| Pulsómetros | Web Bluetooth, servicio estándar *Heart Rate* (0x180D) | Polar H10, H9, OH1 y Verity Sense lo emiten sin pasar por Polar Flow |

## Pulsómetros por Bluetooth

- Funciona en Chrome o Edge en Android, Windows, macOS y ChromeOS.
- **No funciona en Safari de iPhone/iPad.** En iOS se puede usar el navegador Bluefy, o llevar a pista un móvil Android o una tablet.
- Se pueden conectar los dos sensores a la vez desde el mismo dispositivo.
- El sensor debe estar humedecido y en contacto con la piel para empezar a emitir.

## Cálculos (los mismos que en la hoja GESTIÓN ESCUELA)

- FC máxima teórica: 220 − edad (sustituible por una FC máxima medida).
- Zonas: Z1 50–60 %, Z2 60–70 %, Z3 70–80 %, Z4 80–90 %, Z5 90–100 %.
- Índice de recuperación: %FC máxima − %FC media de la sesión.
- eTRIMP (Edwards): minutos en Z1 × 1 + Z2 × 2 + … + Z5 × 5.
- Calorías: ecuación de Keytel et al. (2005) con FC, peso, edad y sexo.

## Protección de datos

La frecuencia cardíaca es un dato de salud (art. 9 RGPD). Hace falta consentimiento explícito, y el del padre, madre o tutor en menores de 14 años. El esquema incluye los campos de consentimiento y las políticas de acceso por alumno.
