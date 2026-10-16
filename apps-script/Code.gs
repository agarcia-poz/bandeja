/**
 * Bandeja · envío de emails desde escuelapadelag@gmail.com
 *
 * Instalación (una sola vez, con la sesión de escuelapadelag@gmail.com abierta):
 * 1. Entra en https://script.google.com y crea un proyecto nuevo llamado "Bandeja emails".
 * 2. Pega este archivo entero en Code.gs y guarda.
 * 3. Configuración del proyecto (rueda dentada) → Propiedades del script → Añadir propiedad:
 *      SECRETO = la clave que te dé Claude (la misma se guarda en Supabase)
 * 4. Implementar → Nueva implementación → tipo "Aplicación web":
 *      Ejecutar como: Yo (escuelapadelag@gmail.com)
 *      Quién tiene acceso: Cualquier usuario
 *    Autoriza los permisos de Gmail cuando te los pida.
 * 5. Copia la URL que termina en /exec y pásasela a Claude.
 *
 * Límite de Google para cuentas Gmail gratuitas: unos 100 destinatarios al día.
 */

const NOMBRE_REMITENTE = 'Escuela de Pádel AG';

function doPost(e) {
  try {
    const datos = JSON.parse(e.postData.contents);
    const secreto = PropertiesService.getScriptProperties().getProperty('SECRETO');
    if (!secreto || datos.secreto !== secreto) return respuesta({ ok: false, error: 'No autorizado' });

    const resultados = (datos.emails || []).map(function (m) {
      try {
        MailApp.sendEmail({
          to: m.to,
          subject: m.subject,
          body: m.body,
          htmlBody: m.html || undefined,
          name: m.fromName || NOMBRE_REMITENTE,
          replyTo: m.replyTo || undefined
        });
        return { id: m.id, ok: true };
      } catch (err) {
        return { id: m.id, ok: false, error: String(err) };
      }
    });
    return respuesta({ ok: true, resultados: resultados, cuotaRestante: MailApp.getRemainingDailyQuota() });
  } catch (err) {
    return respuesta({ ok: false, error: String(err) });
  }
}

function doGet() {
  return respuesta({ ok: true, servicio: 'Bandeja emails', cuotaRestante: MailApp.getRemainingDailyQuota() });
}

function respuesta(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}

/** Ejecuta esta función una vez desde el editor para autorizar los permisos de envío. */
function probar() {
  MailApp.sendEmail(Session.getActiveUser().getEmail(), 'Bandeja: prueba de envío', 'Si lees esto, el envío funciona.');
}
