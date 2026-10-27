// Tareas automáticas (cada 10 minutos, lanzadas por pg_cron):
//  1. Al terminar cada clase, se cobra la clase a los fijos del grupo si no se ha pasado lista.
//  2. Una hora antes de cada clase, se envía el aviso de pago a quien tenga el bono agotado o a punto de agotarse.
import { cors, json, servicio, config } from '../_shared/comun.ts';

type Cal = { mover?: Record<string, string>; anular?: string[]; extra?: string[] };
type Grupo = { id: string; nombre: string; dia_semana: number; hora_inicio: string; hora_fin: string; tarifa_id: string; calendario: Cal | null };

const iso = (d: Date) => d.toISOString().slice(0, 10);
const diaUTC = (s: string) => new Date(s + 'T00:00:00Z');
const minutos = (fecha: string, hora: string) => Date.UTC(+fecha.slice(0, 4), +fecha.slice(5, 7) - 1, +fecha.slice(8, 10), +hora.slice(0, 2), +hora.slice(3, 5)) / 60000;

/** Fecha y hora actuales en Madrid, como «pared» (sin zona) */
function ahoraMadrid() {
  const p = Object.fromEntries(new Intl.DateTimeFormat('en-CA', { timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' }).formatToParts(new Date()).map((x) => [x.type, x.value]));
  const fecha = `${p.year}-${p.month}-${p.day}`, hora = `${p.hour}:${p.minute}`;
  return { fecha, hora, min: minutos(fecha, hora) };
}
/** Misma regla que la app: día habitual del grupo con los cambios de calendario */
function fechasClase(g: Grupo, desde: string, hasta: string): string[] {
  const cal = g.calendario || {}; const mov = cal.mover || {}; const anu = new Set(cal.anular || []); const out = new Set<string>();
  const d = diaUTC(desde); d.setUTCDate(d.getUTCDate() - 60); const fin = diaUTC(hasta); fin.setUTCDate(fin.getUTCDate() + 60);
  while (d.getUTCDay() !== g.dia_semana) d.setUTCDate(d.getUTCDate() + 1);
  while (d <= fin) { const x = iso(d); if (!anu.has(x)) out.add(mov[x] || x); d.setUTCDate(d.getUTCDate() + 7); }
  (cal.extra || []).forEach((x) => out.add(x));
  return [...out].filter((x) => x >= desde && x <= hasta).sort();
}
const eur = (n: number) => `${Number(n).toLocaleString('es-ES', { minimumFractionDigits: Number.isInteger(+n) ? 0 : 2, maximumFractionDigits: 2 })} €`;

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  const secreto = await config('CRON_TAREAS');
  if (!secreto || req.headers.get('x-cron-secret') !== secreto) return json({ error: 'No autorizado' }, 401);

  const sb = servicio(); const ahora = ahoraMadrid();
  const { data: aj } = await sb.from('ajustes').select('escuela, umbral_aviso, auto_desde, inicio_temporada').eq('id', 1).single();
  const desdeAuto: string = aj?.auto_desde || ahora.fecha;
  const { data: grupos } = await sb.from('grupos').select('id, nombre, dia_semana, hora_inicio, hora_fin, tarifa_id, calendario').eq('activo', true);
  const { data: alumnos } = await sb.from('alumnos').select('id, nombre, email, grupo_id, modalidad, creado, clases_iniciales').eq('activo', true);
  const { data: tarifas } = await sb.from('tarifas').select('*');
  const res = { cobradas: [] as string[], avisos: 0 };
  const hace14 = iso(new Date(Date.parse(ahora.fecha) - 14 * 864e5)), manana = iso(new Date(Date.parse(ahora.fecha) + 864e5));

  for (const g of (grupos || []) as Grupo[]) {
    const fijos = (alumnos || []).filter((a) => a.grupo_id === g.id && a.modalidad !== 'relevo');
    for (const f of fechasClase(g, hace14 > desdeAuto ? hace14 : desdeAuto, manana)) {
      const ini = minutos(f, g.hora_inicio.slice(0, 5)), fin = minutos(f, g.hora_fin.slice(0, 5));
      // 1. Cobro automático al terminar la clase
      if (ahora.min >= fin) {
        const { data: s } = await sb.from('sesiones').select('id, cerrada').eq('grupo_id', g.id).eq('fecha', f).maybeSingle();
        if (s?.cerrada) continue;
        let id = s?.id;
        if (!id) { const { data: n, error } = await sb.from('sesiones').insert({ grupo_id: g.id, fecha: f }).select('id').single(); if (error) continue; id = n.id; }
        const { count } = await sb.from('asistencia').select('*', { count: 'exact', head: true }).eq('sesion_id', id);
        if (!count) {
          const filas = fijos.filter((a) => String(a.creado).slice(0, 10) <= f).map((a) => ({ sesion_id: id, alumno_id: a.id, estado: 'presente', cobra: true }));
          if (filas.length) await sb.from('asistencia').insert(filas);
          res.cobradas.push(`${g.nombre} ${f}`);
        }
        await sb.from('sesiones').update({ cerrada: true }).eq('id', id);
        continue;
      }
      // 2. Aviso de pago una hora antes
      if (ahora.min >= ini - 60 && ahora.min < ini) {
        const { data: s } = await sb.from('sesiones').select('id, avisos_enviados').eq('grupo_id', g.id).eq('fecha', f).maybeSingle();
        if (s?.avisos_enviados) continue;
        const t = (tarifas || []).find((x) => x.id === g.tarifa_id) || {};
        for (const a of fijos) {
          if (!a.email) continue;
          const [{ data: pagos }, { data: ajs }, { data: asis }] = await Promise.all([
            sb.from('pagos').select('clases').eq('alumno_id', a.id), sb.from('ajustes_clases').select('clases').eq('alumno_id', a.id), sb.from('asistencia').select('cobra').eq('alumno_id', a.id).eq('cobra', true)]);
          const saldo = (a.clases_iniciales || 0) + (pagos || []).reduce((x, p) => x + (p.clases || 0), 0) + (ajs || []).reduce((x, p) => x + (p.clases || 0), 0) - (asis || []).length;
          if (saldo > (aj?.umbral_aviso ?? 1)) continue;
          const nombre = String(a.nombre).split(' ')[0];
          const asunto = saldo < 0 ? 'Tienes clases pendientes de pago' : saldo === 0 ? 'Tu bono está agotado' : saldo === 1 ? 'Hoy es la última clase de tu bono' : `Te quedan ${saldo} clases de tu bono`;
          const estado = saldo < 0 ? `Tienes ${-saldo} ${saldo === -1 ? 'clase' : 'clases'} sin pagar y la de hoy tampoco está cubierta.` : saldo === 0 ? 'Has consumido todas las clases de tu bono, así que la clase de hoy no está cubierta.' : saldo === 1 ? 'La clase de hoy es la última de tu bono.' : `Te quedan ${saldo} clases, contando la de hoy.`;
          const cuerpo = `Hola ${nombre}:\n\nHoy a las ${g.hora_inicio.slice(0, 5)} tienes clase de pádel. ${estado}\n\n${saldo <= 0 ? 'Puedes renovar' : 'Para seguir sin cortes, puedes renovar'} con:\n· Bono de 4 clases: ${eur(t.precio_mes)}\n· Bono de 10 clases: ${eur(t.precio_trimestre)}${t.precio_suelta != null ? `\n· Clase suelta: ${eur(t.precio_suelta)}` : ''}\n\nPuedes pagar por Bizum, transferencia o en efectivo en la pista.\n\n¡Nos vemos en un rato!\n${aj?.escuela ?? ''}`;
          await sb.from('emails').insert({ alumno_id: a.id, destinatario: a.email, nombre_destinatario: a.nombre, tipo: 'aviso', asunto, cuerpo });
          res.avisos++;
        }
        if (s?.id) await sb.from('sesiones').update({ avisos_enviados: true }).eq('id', s.id);
        else await sb.from('sesiones').insert({ grupo_id: g.id, fecha: f, avisos_enviados: true });
      }
    }
  }
  if (res.avisos) {
    const cron = secreto;
    await fetch(`${Deno.env.get('SUPABASE_URL')}/functions/v1/enviar-emails`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-cron-secret': cron ?? '' }, body: '{}' }).catch(() => null);
  }
  return json({ ok: true, ahora: `${ahora.fecha} ${ahora.hora}`, ...res });
});
