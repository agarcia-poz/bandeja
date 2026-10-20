// Redacta con Gemini una interpretación de los datos de pulsómetro y de partidos de un alumno,
// comparados con su grupo y con la escuela. Solo se envían porcentajes y medias (sin nombre, edad ni contacto).
// El texto queda como borrador: el entrenador lo revisa y lo publica desde la app.
import { cors, json, servicio, esAdmin, config } from '../_shared/comun.ts';

const media = (xs: (number | null | undefined)[]) => { const v = xs.filter((x): x is number => x != null && !Number.isNaN(x)); return v.length ? v.reduce((a, b) => a + b, 0) / v.length : null; };
const r2 = (x: number | null) => (x == null ? null : Math.round(x * 100) / 100);
const edadDe = (f: string | null) => (f ? Math.floor((Date.now() - new Date(f).getTime()) / 31557600000) : 30);
type Fila = Record<string, number | null> & { alumno: string; grupo: string | null };

function agregar(filas: Fila[], claves: string[]) {
  const porAl: Record<string, { grupo: string | null; f: Fila[] }> = {};
  filas.forEach((f) => { (porAl[f.alumno] ??= { grupo: f.grupo, f: [] }).f.push(f); });
  const al = Object.entries(porAl).map(([id, v]) => ({ id, grupo: v.grupo, n: v.f.length, ...Object.fromEntries(claves.map((k) => [k, media(v.f.map((x) => x[k]))])) })) as (Record<string, number | null> & { id: string; grupo: string | null; n: number })[];
  const agg = (l: typeof al) => Object.fromEntries(claves.map((k) => [k, r2(media(l.map((x) => x[k])))]));
  return { al, alumno: (id: string) => al.find((x) => x.id === id), grupo: (g: string | null) => agg(al.filter((x) => x.grupo === g)), escuela: agg(al) };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (!(await esAdmin(req))) return json({ error: 'Solo el administrador puede generar informes' }, 401);
  const key = await config('GEMINI_API_KEY');
  if (!key) return json({ error: 'Falta la clave de Gemini' }, 500);
  const { alumno_id } = await req.json().catch(() => ({}));
  if (!alumno_id) return json({ error: 'Falta alumno_id' }, 400);

  const sb = servicio();
  const { data: aj } = await sb.from('ajustes').select('temporada, inicio_temporada').eq('id', 1).single();
  const { data: alumnos } = await sb.from('alumnos').select('id, grupo_id, fecha_nacimiento, activo');
  const yo = (alumnos ?? []).find((a) => a.id === alumno_id);
  if (!yo) return json({ error: 'Alumno no encontrado' }, 404);
  const info = Object.fromEntries((alumnos ?? []).map((a) => [a.id, a]));

  const { data: fc } = await sb.from('registros_fc').select('alumno_id, fecha, duracion_min, fc_media, fc_max, zonas_min, kcal').gte('fecha', aj!.inicio_temporada).order('fecha');
  const filasFC: Fila[] = (fc ?? []).filter((r) => info[r.alumno_id]).map((r) => {
    const max = 220 - edadDe(info[r.alumno_id].fecha_nacimiento); const t = r.zonas_min.reduce((s: number, m: number, i: number) => s + m * (i + 1), 0);
    return { alumno: r.alumno_id, grupo: info[r.alumno_id].grupo_id, fc_media_pct: r.fc_media / max, fc_max_pct: r.fc_max / max, recuperacion_pct: (r.fc_max - r.fc_media) / max, etrimp_por_min: t / (r.duracion_min || 1), kcal_por_min: (r.kcal ?? 0) / (r.duracion_min || 1) };
  });
  const { data: st } = await sb.from('stats_jugador').select('alumno_id, fecha, ganado, enf, win, pct_enf, pct_win, pct_oro, pct_break, ppj, indice, g_enf, g_win').gte('fecha', aj!.inicio_temporada).order('fecha');
  const filasP: Fila[] = (st ?? []).filter((r) => info[r.alumno_id]).map((r) => ({ alumno: r.alumno_id, grupo: info[r.alumno_id].grupo_id, pct_errores_no_forzados: r.pct_enf, pct_winners: r.pct_win, errores_por_partido: r.enf, winners_por_partido: r.win, pct_puntos_oro: r.pct_oro, pct_roturas: r.pct_break, puntos_por_juego: r.ppj, indice_win: r.indice, ganado: r.ganado == null ? null : r.ganado ? 1 : 0 }));

  const kFC = ['fc_media_pct', 'fc_max_pct', 'recuperacion_pct', 'etrimp_por_min', 'kcal_por_min'];
  const kP = ['pct_errores_no_forzados', 'pct_winners', 'errores_por_partido', 'winners_por_partido', 'pct_puntos_oro', 'pct_roturas', 'puntos_por_juego', 'indice_win', 'ganado'];
  const A = agregar(filasFC, kFC), B = agregar(filasP, kP);
  const misFC = filasFC.filter((f) => f.alumno === alumno_id);
  const misP = (st ?? []).filter((r) => r.alumno_id === alumno_id);
  if (misFC.length < 2 && !misP.length) return json({ error: 'Hacen falta al menos 2 sesiones con pulsómetro o un partido' }, 400);

  const datos = {
    temporada: aj!.temporada,
    pulsometro: misFC.length ? {
      sesiones: misFC.map((f) => Object.fromEntries(kFC.map((k) => [k, r2(f[k])]))),
      media_alumno: Object.fromEntries(kFC.map((k) => [k, r2(A.alumno(alumno_id)?.[k] ?? null)])),
      media_grupo: A.grupo(yo.grupo_id), media_escuela: A.escuela
    } : null,
    partidos: misP.length ? {
      partidos: misP.map((r) => ({ ganado: r.ganado, errores_no_forzados: r.enf, winners: r.win, pct_errores_no_forzados: r2(r.pct_enf), pct_winners: r2(r.pct_win), golpe_mas_errores: r.g_enf, golpe_mas_winners: r.g_win, pct_puntos_oro: r2(r.pct_oro), pct_roturas: r2(r.pct_break), puntos_por_juego: r2(r.ppj), indice_win: r2(r.indice) })),
      media_alumno: Object.fromEntries(kP.map((k) => [k, r2(B.alumno(alumno_id)?.[k] ?? null)])),
      media_grupo: B.grupo(yo.grupo_id), media_escuela: B.escuela
    } : null
  };

  const system = `Eres el preparador de una escuela de pádel. Escribes al alumno, de tú, en español de España, con un tono cercano, motivador y riguroso.
Te paso sus datos de la temporada y las medias de su grupo y de toda la escuela.
Pulsómetro: porcentajes sobre su FC máxima teórica; zonas Z1 50-60 %, Z2 60-70 %, Z3 70-80 %, Z4 80-90 %, Z5 90-100 %. Índice de recuperación = %FC máx − %FC media (más alto = baja mejor las pulsaciones entre esfuerzos). eTRIMP = carga de entrenamiento.
Partidos: % errores no forzados = sus errores sobre los puntos que perdió su pareja (más bajo es mejor). % winners = sus winners sobre los puntos que ganó su pareja. Índice win = media de % puntos de oro ganados y % roturas conseguidas. Golpes: S saque, D derecha, R revés, PD pared derecha, PR pared revés, CP contrapared, VD volea derecha, VR volea revés, B bandeja, RMP remate plano, RML remate liftado.
Escribe entre 3 y 5 párrafos breves, sin títulos, listas ni markdown: cómo trabaja su corazón en clase frente a su grupo y la escuela; qué dicen sus partidos (errores, winners, golpes más fuertes y más débiles, momentos clave); evolución si se aprecia; y 2 o 3 recomendaciones concretas para pista. Cita cifras redondeadas. Usa solo los datos del JSON. No hagas diagnósticos médicos; si algo parece anómalo, sugiere comentarlo con el entrenador.`;

  const modelos = [...new Set([(await config('GEMINI_MODEL')) || 'gemini-flash-latest', 'gemini-flash-latest', 'gemini-flash-lite-latest'])];
  let texto = '', ultimoError = '';
  for (const modelo of modelos) {
    const resp = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent`, {
      method: 'POST',
      headers: { 'x-goog-api-key': key, 'content-type': 'application/json' },
      body: JSON.stringify({ systemInstruction: { parts: [{ text: system }] }, contents: [{ role: 'user', parts: [{ text: `Datos (JSON):\n${JSON.stringify(datos)}` }] }], generationConfig: { temperature: 0.6, maxOutputTokens: 4096 } })
    });
    const out = await resp.json().catch(() => ({}));
    if (!resp.ok) { ultimoError = out?.error?.message ?? `Error ${resp.status}`; continue; }
    texto = (out.candidates?.[0]?.content?.parts ?? []).filter((p: { text?: string; thought?: boolean }) => p.text && !p.thought).map((p: { text: string }) => p.text).join('\n').trim();
    if (texto) break;
    ultimoError = 'Gemini devolvió una respuesta vacía';
  }
  if (!texto) return json({ error: ultimoError || 'Gemini no respondió' }, 502);

  const { data: inf, error } = await sb.from('informes_ia').insert({ alumno_id, texto, publicado: false }).select('id, texto, generado, publicado').single();
  if (error) return json({ error: error.message }, 500);
  return json(inf);
});
