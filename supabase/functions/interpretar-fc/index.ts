// Redacta con IA una interpretación de los datos de frecuencia cardíaca y condición física de un alumno.
// El texto se guarda como borrador; el entrenador lo revisa y lo publica desde la app.
import { cors, json, servicio, esAdmin } from '../_shared/comun.ts';

const media = (xs: number[]) => (xs.length ? xs.reduce((a, b) => a + b, 0) / xs.length : null);
const r1 = (x: number | null) => (x == null ? null : Math.round(x * 1000) / 10);

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!(await esAdmin(req))) return json({ error: 'Solo el administrador puede generar informes' }, 401);
  const key = Deno.env.get('ANTHROPIC_API_KEY');
  if (!key) return json({ error: 'Falta configurar ANTHROPIC_API_KEY en Supabase' }, 500);

  const { alumno_id } = await req.json().catch(() => ({}));
  if (!alumno_id) return json({ error: 'Falta alumno_id' }, 400);
  const sb = servicio();
  const { data: aj } = await sb.from('ajustes').select('temporada, inicio_temporada').eq('id', 1).single();
  const { data: a } = await sb.from('alumnos').select('id, sexo, fecha_nacimiento, peso_kg, grupo_id, grupos(nombre, nivel)').eq('id', alumno_id).single();
  if (!a) return json({ error: 'Alumno no encontrado' }, 404);

  const edad = a.fecha_nacimiento ? Math.floor((Date.now() - new Date(a.fecha_nacimiento).getTime()) / 31557600000) : 30;
  const fcmax = 220 - edad;
  const { data: propias } = await sb.from('registros_fc').select('fecha, duracion_min, fc_media, fc_max, zonas_min, kcal').eq('alumno_id', a.id).gte('fecha', aj!.inicio_temporada).order('fecha');
  if (!propias?.length || propias.length < 2) return json({ error: 'Hacen falta al menos 2 sesiones con pulsómetro' }, 400);

  const { data: companeros } = await sb.from('alumnos').select('id, fecha_nacimiento').eq('grupo_id', a.grupo_id).neq('id', a.id);
  const ids = (companeros ?? []).map((c) => c.id);
  const edades = Object.fromEntries((companeros ?? []).map((c) => [c.id, c.fecha_nacimiento ? Math.floor((Date.now() - new Date(c.fecha_nacimiento).getTime()) / 31557600000) : 30]));
  const { data: grupoFC } = ids.length ? await sb.from('registros_fc').select('alumno_id, fc_media, fc_max').in('alumno_id', ids).gte('fecha', aj!.inicio_temporada) : { data: [] };
  const { data: tests } = await sb.from('tests_fisicos').select('temporada, periodo, agilidad_1, agilidad_2, agilidad_3, precision, rpe').eq('alumno_id', a.id).order('fecha');

  const sesiones = propias.map((s) => ({
    fecha: s.fecha, minutos: s.duracion_min, fc_media_ppm: s.fc_media, fc_max_ppm: s.fc_max,
    fc_media_pct: r1(s.fc_media / fcmax), fc_max_pct: r1(s.fc_max / fcmax), indice_recuperacion_pct: r1((s.fc_max - s.fc_media) / fcmax),
    minutos_zona: { z1: s.zonas_min[0], z2: s.zonas_min[1], z3: s.zonas_min[2], z4: s.zonas_min[3], z5: s.zonas_min[4] },
    etrimp: s.zonas_min.reduce((t: number, m: number, i: number) => t + m * (i + 1), 0), kcal: s.kcal
  }));
  const grupo = {
    fc_media_pct: r1(media((grupoFC ?? []).map((g) => g.fc_media / (220 - edades[g.alumno_id])))),
    indice_recuperacion_pct: r1(media((grupoFC ?? []).map((g) => (g.fc_max - g.fc_media) / (220 - edades[g.alumno_id])))),
    sesiones: (grupoFC ?? []).length
  };

  const datos = { edad, sexo: a.sexo === 'F' ? 'mujer' : 'hombre', fc_max_teorica: fcmax, grupo: (a as any).grupos?.nombre, nivel: (a as any).grupos?.nivel, temporada: aj!.temporada, sesiones, media_del_grupo: grupo, tests_condicion_fisica: tests ?? [] };

  const system = `Eres el preparador físico de una escuela de pádel. Escribes al alumno, de tú, en español de España, con un tono cercano y motivador pero riguroso.
Interpretas sus datos de frecuencia cardíaca registrados con pulsómetro en clase y sus tests de condición física.
Conceptos: zonas Z1 50-60 %, Z2 60-70 %, Z3 70-80 %, Z4 80-90 %, Z5 90-100 % de la FC máxima teórica (220 - edad). Índice de recuperación = %FC máx - %FC media de la sesión (más alto indica más capacidad de bajar pulsaciones entre esfuerzos). eTRIMP de Edwards = suma de minutos por zona × número de zona. En agilidad, menos segundos es mejor; en precisión, más puntos es mejor.
Escribe 3 o 4 párrafos breves, sin títulos ni listas ni markdown: 1) cómo trabaja su corazón en clase comparado con su grupo, 2) evolución a lo largo de las sesiones, 3) condición física si hay tests, 4) una o dos recomendaciones concretas para pista o fuera de ella.
No hagas diagnósticos médicos. Si ves valores anómalos (por ejemplo FC máxima por encima de la teórica de forma repetida), sugiere comentarlo con el entrenador, sin alarmar. No inventes datos que no estén en el JSON.`;

  const resp = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json' },
    body: JSON.stringify({
      model: Deno.env.get('ANTHROPIC_MODEL') ?? 'claude-sonnet-5-5',
      max_tokens: 1000,
      system,
      messages: [{ role: 'user', content: `Datos del alumno (JSON):\n${JSON.stringify(datos)}` }]
    })
  });
  const out = await resp.json();
  if (!resp.ok) return json({ error: out?.error?.message ?? 'Error de la API de IA' }, 502);
  const texto = (out.content ?? []).filter((c: { type: string }) => c.type === 'text').map((c: { text: string }) => c.text).join('\n').trim();

  const { data: inf, error } = await sb.from('informes_ia').insert({ alumno_id: a.id, texto, publicado: false }).select('id, texto, generado, publicado').single();
  if (error) return json({ error: error.message }, 500);
  return json(inf);
});
