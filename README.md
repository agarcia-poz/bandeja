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
| `icon.svg`, `icon-*.png`, `og.png`, `manifest.webmanifest` | GitHub Pages | Icono de la app, miniatura al compartir el enlace e instalación en la pantalla de inicio |
| `.github/workflows/mantener-activo.yml` | GitHub Actions | Consulta mínima cada 3 días para que Supabase no pause el proyecto |

## Configuración privada

La URL del script de Gmail, su secreto y las claves de IA (`GROQ_API_KEY`, `GEMINI_API_KEY`; opcionalmente `GROQ_MODEL`, `GEMINI_MODEL` e `IA_ORDEN`) están en la tabla `config_privada` de Supabase, que solo leen las funciones del servidor. Nunca en este repositorio.

## Portal del alumno

- **Inicio:** bono, asistencia, carga de la semana, partidos ganados y conclusiones automáticas (bono, asistencia, intensidad, carga, punto fuerte y aspecto a mejorar frente al grupo).
- **Mi corazón:** gráfico con los datos a elegir (FC media, FC máxima, carga, calorías, minutos, media del grupo), carga semanal de las últimas 8 semanas y relación carga semanal / media del mes (Gabbett, 2016).
- **Avisos:** emails recibidos y todo lo registrado (pagos, clases, pulso y partidos).

## Recordatorio de WhatsApp

En el panel hay un editor de mensajes de WhatsApp. El mensaje predeterminado saluda según la hora y recuerda la hora del entrenamiento del grupo elegido. Se elige el grupo con un botón y el texto se actualiza con su día y su hora. Se pueden crear y guardar otros mensajes; los datos entre llaves ({saludo}, {cuando}, {hora}, {hora_fin}, {grupo}, {contenido}…) se rellenan solos. «Enviar por WhatsApp» abre WhatsApp con el texto para elegir el grupo. WhatsApp no ofrece una forma gratuita de enviar mensajes automáticos a grupos: su API oficial para grupos es de pago, requiere cuenta de empresa verificada y admite como mucho 8 participantes.

## Pulsómetros

Web Bluetooth con el servicio estándar *Heart Rate*. Funciona en Chrome o Edge (Android, Windows, macOS, ChromeOS). No funciona en Safari de iPhone/iPad, tampoco añadiendo la app a la pantalla de inicio; allí se puede usar el navegador Bluefy.

- Si un sensor aparece pero no conecta, casi siempre está conectado a otra app o dispositivo (Polar Flow, Polar Beat, reloj, ajustes de Bluetooth del iPhone). La app reintenta tres veces, explica la causa probable y permite «Buscar todos los dispositivos».
- Si se cae la conexión durante la sesión, intenta reconectar sola.
- Al guardar la sesión, cada alumno recibe por email un resumen visual (fases, curva de pulso, comparativas e interpretación con referencias: ACSM 2018, OMS 2020, Díaz García et al. 2017, Carbonell Martínez et al. 2017, Edwards 1993).

## Alumnos y emails

- Al dar de alta se puede marcar o desmarcar «Enviar ahora el email de bienvenida». Así se puede dar de alta a todo el mundo sin enviar nada.
- En *Alumnos* cada fila tiene una casilla y la cabecera una para marcar todos. El botón «Seleccionar los que aún no lo han recibido» marca a quienes no tienen la bienvenida enviada; después, «Enviar email de bienvenida» manda a cada uno su código. Cada alumno muestra si la bienvenida está sin enviar, en cola, enviada o si ya activó su acceso.
- Gmail permite unos 100 emails al día desde una cuenta gratuita: la app no deja enviar más de 90 de una vez.
- Al registrar un pago, el alumno recibe un email de agradecimiento con el pago y el estado de su bono.

## Calendario de clases

Las clases se generan a partir del día y la hora de cada grupo. En *Clases* (o desde el diseño de la sesión, con «Cambiar fecha») se puede:
- **Mover una clase** a otra fecha. Su diseño, sus contenidos y la lista, si ya se pasó, se mueven con ella.
- **Anular una clase.** No se celebra y no se cobra.
- **Añadir una clase extra**, por ejemplo para recuperar una anulada.

Cada cambio aparece en la lista «Cambios en el calendario» y se puede deshacer.

## Diseño de sesiones

En *Clases*, cada sesión tiene un botón «Diseñar la sesión», con los mismos campos que la hoja de sesión de la escuela:

- **Cabecera:** número de sesión (se calcula solo), nivel, contenidos y objetivos de carga (minutos por encima del 90 % de la FC máxima y RPE objetivo).
- **Fases:** calentamiento, técnica, táctica y partido, y opcionalmente físico o vuelta a la calma. Cada fase tiene tareas con minutos, descripción y, si hacen falta, físico, competición, variante, objetivo y puntuación. Las fases y las tareas se pueden reordenar, duplicar y borrar.
- **Tiempo:** una barra muestra los minutos planificados frente a la duración de la clase.
- **Varias pistas:** «Versión para otra pista» crea una copia de la sesión para cambiarla, como las dos mitades de la hoja.
- **Aplicar a otras clases:** desde el diseño se eligen otras clases (de cualquier grupo; hay un botón para marcar la de esta semana de cada grupo). Al guardar reciben el mismo diseño, cada una con su nº de sesión y el nivel de su grupo, y se vuelven a actualizar cada vez que se guarda el original. Una copia se puede hacer independiente.
- **Reutilizar:** se puede copiar la sesión anterior, copiar cualquier otra sesión o reutilizar tareas ya usadas en esa fase.
- **Imprimir:** sale en A4 apaisado con el formato de la hoja de sesión (dos mitades; si hay una sola pista, se repite).
- **Pulsómetros:** si ese día hubo sesión de pulsómetros, se muestra el tiempo real por encima del 90 % junto al objetivo.
- **Portal del alumno:** los contenidos aparecen en sus próximas clases. Si se marca «La sesión completa», el alumno también puede abrir la sesión con sus tareas.

## Bonos, fijos y relevos

- **Fijo del grupo:** se le cobra cada clase con lista pasada, aunque falte, salvo que le cubra un relevo.
- **Relevo:** pertenece a un grupo, pero solo se le cobra la clase cuando viene. Cualquier alumno puede añadirse a la lista de otro grupo.
- **Ajustes:** desde la ficha del alumno se suman o restan clases con un motivo (por ejemplo, una clase que no hay que cobrarle).
- Saldo = clases pagadas + ajustes − clases cobradas.

## Gastos y balance

En *Pagos* hay cuatro pestañas: cobros, gastos (por categoría), balance mensual con ingresos, gastos, resultado, margen y clases impartidas, y *Precios*, donde se cambian el nombre de cada tarifa y el precio del bono de 4 clases, el de 10 y la clase suelta. Los precios nuevos se aplican a los pagos que se registren después; los pagos ya hechos no cambian.

## Bajas de alumnos y grupos

- **Dar de baja** (desde la ficha o seleccionando varios en *Alumnos*): el alumno desaparece de las listas y no puede entrar en la app, pero sus pagos siguen en el balance.
- **Eliminar con todos sus datos:** borra también pagos, asistencia, pulsaciones y estadísticas. No se puede deshacer.
- **Eliminar grupo** (en *Alumnos* → filtro del grupo → *Editar grupo*): sus alumnos pasan a «Sin grupo» y las clases ya pasadas se conservan, así que los bonos no cambian.

## Marcador: partidos y juegos tácticos (hoja ANÁLISIS ESTADÍSTICO)

- **Juego táctico:** por defecto, 2 rondas a 15 puntos (se puede cambiar, y elegir si hay que ganar por 2). No hay sorteo: se elige qué pareja saca la primera ronda. En cada ronda saca siempre la misma pareja; en la siguiente, la otra (2, 4 o 6 rondas). Gana la pareja con mejor balance de puntos (ganados − perdidos) al terminar todas las rondas; si el balance es igual, empate. Sus estadísticas se guardan aparte de las de los partidos.
- **Punto doble:** antes de anotar el punto se pulsa «×2». En partido cuenta como dos puntos; si la pareja que lo gana iba 30-40, pasa a ventaja/40, y si pierde esa ventaja se vuelve a 40-40 con punto de oro. En juego táctico suma 2 al marcador.
- El alumnado también puede registrar partidos desde su portal (por ejemplo, un familiar con su móvil). Aparecen en el marcador con «Registrado por».

- Cada punto se registra como winner o error no forzado de un jugador con su golpe (S, D, R, PD, PR, CP, VD, VR, B, RMP, RML), o como punto sin winner ni error.
- El marcador lleva sets, juegos, tie-break a 6-6, punto de oro o ventajas, saque y bolas de break.
- Sorteo con moneda, primer sacador y sacador de la otra pareja; el orden queda fijo en el set y se puede cambiar al empezar cada set. Las parejas cambian de lado en pantalla en cada set.
- En cada punto de oro la app pregunta qué jugador de la pareja que resta ha elegido restar. Si no se indicó, se puede completar o corregir después tocando el punto en «Últimos puntos». El informe del partido tiene una tabla «Puntos de oro al resto» (restados, ganados, perdidos y % por jugador) y el alumno ve sus totales en «Momentos clave».
- Estadística de saque y resto por pareja y por jugador.
- % ENF = errores del jugador / puntos perdidos por su pareja. % WIN = winners del jugador / puntos ganados por su pareja.
- Índice win = media de % puntos de oro ganados y % roturas conseguidas.
- En *Mis partidos* el alumno ve sus estadísticas agrupadas en Resultado, Ataque, Errores no forzados, Saque, Resto y Momentos clave, cada una comparada con su grupo y con la escuela; su perfil de golpes, su evolución partido a partido y una tabla con cada pareja con la que ha jugado.

## Cálculos de pulsómetro (hoja GESTIÓN ESCUELA)

- FC máxima teórica: 220 − edad.
- Zonas: Z1 50–60 %, Z2 60–70 %, Z3 70–80 %, Z4 80–90 %, Z5 90–100 %.
- Índice de recuperación: %FC máxima − %FC media.
- eTRIMP (Edwards): minutos en Z1 × 1 + … + Z5 × 5.
- Calorías: ecuación de Keytel et al. (2005).

## Animaciones

- Al cambiar de pantalla, los bloques entran escalonados y las cifras principales cuentan hasta su valor.
- Pulsómetros: el % sube o baja de forma continua, una flecha indica si la frecuencia está subiendo o bajando, el corazón late al ritmo real, un medidor de fases marca la posición dentro de la zona y, al cambiar de fase, una onda del color de la nueva zona recorre la tarjeta.
- Marcador: los números giran al cambiar, la fila de la pareja que gana el punto se ilumina y hay celebraciones al ganar un juego, un set o el partido. En el punto de oro el marcador pasa a modo dorado y se resalta la pareja que resta.
- Si el dispositivo tiene activado «reducir movimiento», las animaciones se desactivan.

## Protección de datos

La frecuencia cardíaca es un dato de salud (art. 9 RGPD): la ficha recoge el consentimiento (y el tutor en menores). Cada alumno solo puede leer sus propios datos; las comparativas con el grupo se calculan sobre datos anónimos. Para los informes con Gemini solo se envían porcentajes y medias, sin nombre, edad ni contacto. En el plan gratuito de la API de Gemini, Google puede usar lo que se le envía para mejorar sus productos.
