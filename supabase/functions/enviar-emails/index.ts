// Envía los emails en cola a través del script de Google Apps Script de la cuenta de Gmail de la escuela.
import { cors, json, servicio, esAdmin } from '../_shared/comun.ts';

const escapar = (s: string) => s.replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]!));

function plantilla(asunto: string, cuerpo: string, escuela: string) {
  const parrafos = escapar(cuerpo).split(/\n{2,}/).map((p) => `<p style="margin:0 0 14px">${p.replace(/\n/g, '<br>')}</p>`).join('');
  return `<!doctype html><html><body style="margin:0;background:#ECF2FA;font-family:Helvetica,Arial,sans-serif;color:#0C1B38">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#ECF2FA;padding:24px 12px"><tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden">
    <tr><td style="background:#1A4EBA;padding:20px 24px;color:#ffffff">
      <div style="font-size:13px;opacity:.85">${escapar(escuela)}</div>
      <div style="font-size:22px;font-weight:bold;margin-top:4px">${escapar(asunto)}</div>
    </td></tr>
    <tr><td style="padding:24px;font-size:15px;line-height:1.55">${parrafos}</td></tr>
    <tr><td style="height:6px;background:#D6EA28"></td></tr>
  </table></td></tr></table></body></html>`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!(await esAdmin(req))) return json({ error: 'Solo el administrador puede enviar emails' }, 401);

  const url = Deno.env.get('APPS_SCRIPT_URL');
  const secreto = Deno.env.get('APPS_SCRIPT_SECRETO');
  if (!url || !secreto) return json({ error: 'Falta configurar APPS_SCRIPT_URL o APPS_SCRIPT_SECRETO' }, 500);

  const sb = servicio();
  const { data: aj } = await sb.from('ajustes').select('escuela, remitente').eq('id', 1).single();
  const { data: cola, error } = await sb.from('emails').select('*').eq('estado', 'en_cola').order('creado').limit(40);
  if (error) return json({ error: error.message }, 500);
  if (!cola?.length) return json({ enviados: 0, errores: 0 });

  const escuela = aj?.escuela ?? 'Escuela de Pádel';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      secreto,
      emails: cola.map((m) => ({ id: m.id, to: m.destinatario, subject: m.asunto, body: m.cuerpo, html: plantilla(m.asunto, m.cuerpo, escuela), fromName: escuela, replyTo: aj?.remitente }))
    }),
    redirect: 'follow'
  });
  let r: { ok: boolean; error?: string; resultados?: { id: string; ok: boolean; error?: string }[]; cuotaRestante?: number };
  try { r = await res.json(); } catch { return json({ error: 'El script de Gmail no respondió con JSON. Revisa la implementación.' }, 502); }
  if (!r.ok) return json({ error: r.error ?? 'Error en el script de Gmail' }, 502);

  let enviados = 0, errores = 0;
  for (const x of r.resultados ?? []) {
    if (x.ok) { enviados++; await sb.from('emails').update({ estado: 'enviado', enviado: new Date().toISOString(), error: null }).eq('id', x.id); }
    else { errores++; await sb.from('emails').update({ estado: 'error', error: x.error }).eq('id', x.id); }
  }
  return json({ enviados, errores, cuotaRestante: r.cuotaRestante });
});
