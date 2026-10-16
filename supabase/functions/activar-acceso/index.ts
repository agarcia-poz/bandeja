// El alumno activa su acceso con el código de la escuela + su email, y elige contraseña.
import { cors, json, servicio } from '../_shared/comun.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  let body: { codigo?: string; email?: string; password?: string };
  try { body = await req.json(); } catch { return json({ error: 'Petición no válida' }, 400); }
  const codigo = (body.codigo ?? '').trim().toUpperCase();
  const email = (body.email ?? '').trim().toLowerCase();
  const password = body.password ?? '';
  if (!codigo || !email) return json({ error: 'Escribe tu código y tu email' }, 400);
  if (password.length < 8) return json({ error: 'La contraseña debe tener al menos 8 caracteres' }, 400);

  const sb = servicio();
  const { data: alumno } = await sb.from('alumnos').select('id, email, user_id, activo').eq('codigo_acceso', codigo).maybeSingle();
  if (!alumno || !alumno.activo || alumno.email.trim().toLowerCase() !== email) {
    return json({ error: 'El código y el email no coinciden con ningún alumno. Usa el email que diste al inscribirte.' }, 404);
  }
  if (alumno.user_id) return json({ error: 'Este acceso ya está activado. Entra con tu email y contraseña.' }, 409);

  const { data: creado, error } = await sb.auth.admin.createUser({ email, password, email_confirm: true });
  if (error || !creado?.user) return json({ error: error?.message?.includes('already') ? 'Ya existe una cuenta con ese email. Entra con tu contraseña.' : 'No se pudo crear el acceso' }, 409);

  await sb.from('alumnos').update({ user_id: creado.user.id }).eq('id', alumno.id);
  return json({ ok: true });
});
