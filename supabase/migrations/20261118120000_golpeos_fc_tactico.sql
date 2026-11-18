-- Golpeos por clase, frecuencia cardíaca en winners/errores y email tras partido o juego táctico.
-- Solo añade columnas, un disparador y un tipo de email: no borra nada.

-- 1. Golpeos del diseño de sesión (total, margen del 5 % y reparto por golpe) y asistentes confirmados.
--    Con ambos datos cada alumno (o la app del alumno) puede calcular sus golpeos individuales.
alter table public.sesiones add column if not exists golpeos jsonb;
alter table public.sesiones add column if not exists asistentes int not null default 0;

create or replace function public.contar_asistentes() returns trigger
language plpgsql security definer set search_path = '' as
$$
declare sid uuid := coalesce(new.sesion_id, old.sesion_id);
begin
  update public.sesiones
     set asistentes = (select count(*) from public.asistencia where sesion_id = sid and estado = 'presente')
   where id = sid;
  return null;
end
$$;
revoke all on function public.contar_asistentes() from public, anon, authenticated;

drop trigger if exists asistencia_cuenta on public.asistencia;
create trigger asistencia_cuenta after insert or update or delete on public.asistencia
  for each row execute function public.contar_asistentes();

update public.sesiones s
   set asistentes = (select count(*) from public.asistencia a where a.sesion_id = s.id and a.estado = 'presente');

-- 2. FC media (% de su FC máxima) cuando el jugador hace un winner o un error no forzado, y reparto por zonas.
alter table public.stats_jugador
  add column if not exists fc_win numeric,
  add column if not exists fc_enf numeric,
  add column if not exists fc_zonas jsonb;

-- 3. Nuevo tipo de email: resumen tras un partido o juego táctico.
alter table public.emails drop constraint if exists emails_tipo_check;
alter table public.emails add constraint emails_tipo_check
  check (tipo = any (array['confirmacion','aviso','bienvenida','sesion','partido']));

-- 4. Comparativa anónima: añade la FC en winners y errores.
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
    'sesiones', coalesce((select jsonb_agg(jsonb_build_object('k', o.k, 'fecha', r.fecha, 'duracion', r.duracion_min, 'fcMed', r.fc_media, 'fcMax', r.fc_max, 'zonas', to_jsonb(r.zonas_min), 'kcal', r.kcal, 'tipo', r.tipo))
                          from public.registros_fc r join otros o on o.id = r.alumno_id, aj where r.fecha >= aj.inicio_temporada), '[]'::jsonb),
    'partidos', coalesce((select jsonb_agg(jsonb_build_object('k', o.k, 'grupo', o.grupo_id, 'p', substr(md5(s.partido_id::text), 1, 8), 'fecha', s.fecha, 'ganado', s.ganado, 'modo', s.modo,
                            'enf', s.enf, 'win', s.win, 'pct_enf', s.pct_enf, 'pct_win', s.pct_win, 'pct_oro', s.pct_oro, 'pct_break', s.pct_break, 'ppj', s.ppj, 'indice', s.indice,
                            'pct_puntos', s.pct_puntos, 'pct_saque', s.pct_saque, 'pct_saque_pareja', s.pct_saque_pareja, 'pct_resto_pareja', s.pct_resto_pareja,
                            'pct_juegos_saque', s.pct_juegos_saque, 'pct_oro_resto', s.pct_oro_resto, 'fc_win', s.fc_win, 'fc_enf', s.fc_enf))
                          from public.stats_jugador s join otros o on o.id = s.alumno_id, aj where s.fecha >= aj.inicio_temporada), '[]'::jsonb)
  ) end
$$;
revoke all on function public.comparativa() from public, anon;
grant execute on function public.comparativa() to authenticated;
