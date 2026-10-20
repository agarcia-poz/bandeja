-- Estadísticas ampliadas por jugador (vista del alumno por categorías)
alter table public.stats_jugador
  add column if not exists pct_puntos numeric,
  add column if not exists pct_saque numeric,
  add column if not exists pct_saque_pareja numeric,
  add column if not exists pct_resto_pareja numeric,
  add column if not exists pct_juegos_saque numeric,
  add column if not exists pct_oro_resto numeric;

create or replace function public.comparativa() returns jsonb
language sql stable security definer set search_path = '' as
$$
  with yo as (select public.mi_alumno_id() as id),
       aj as (select temporada, inicio_temporada from public.ajustes where id = 1),
       otros as (
         select a.id, a.grupo_id, a.sexo,
                coalesce(extract(year from age(a.fecha_nacimiento))::int, 30) as edad,
                'X' || substr(md5(a.id::text || 'bandeja'), 1, 10) as k
         from public.alumnos a, yo
         where a.activo and a.id is distinct from yo.id
       )
  select case when (select auth.uid()) is null then null else jsonb_build_object(
    'alumnos', coalesce((select jsonb_agg(jsonb_build_object('k', k, 'grupo', grupo_id, 'edad', edad, 'sexo', sexo)) from otros), '[]'::jsonb),
    'sesiones', coalesce((select jsonb_agg(jsonb_build_object('k', o.k, 'fecha', r.fecha, 'duracion', r.duracion_min, 'fcMed', r.fc_media, 'fcMax', r.fc_max, 'zonas', to_jsonb(r.zonas_min), 'kcal', r.kcal))
                          from public.registros_fc r join otros o on o.id = r.alumno_id, aj where r.fecha >= aj.inicio_temporada), '[]'::jsonb),
    'partidos', coalesce((select jsonb_agg(jsonb_build_object('k', o.k, 'grupo', o.grupo_id, 'p', substr(md5(s.partido_id::text), 1, 8), 'fecha', s.fecha, 'ganado', s.ganado,
                            'enf', s.enf, 'win', s.win, 'pct_enf', s.pct_enf, 'pct_win', s.pct_win, 'pct_oro', s.pct_oro, 'pct_break', s.pct_break, 'ppj', s.ppj, 'indice', s.indice,
                            'pct_puntos', s.pct_puntos, 'pct_saque', s.pct_saque, 'pct_saque_pareja', s.pct_saque_pareja, 'pct_resto_pareja', s.pct_resto_pareja,
                            'pct_juegos_saque', s.pct_juegos_saque, 'pct_oro_resto', s.pct_oro_resto))
                          from public.stats_jugador s join otros o on o.id = s.alumno_id, aj where s.fecha >= aj.inicio_temporada), '[]'::jsonb)
  ) end
$$;
revoke all on function public.comparativa() from public, anon;
grant execute on function public.comparativa() to authenticated;
