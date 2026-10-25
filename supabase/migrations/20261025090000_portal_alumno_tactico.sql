-- Portal del alumno: registros propios de FC en partidos, sus emails, sus partidos
-- Marcador: juegos tácticos y punto doble

-- 1. Frecuencia cardíaca: entrenamiento (lo registra la escuela) o partido (lo registra el alumno)
alter table public.registros_fc add column if not exists tipo text not null default 'entrenamiento';
alter table public.registros_fc drop constraint if exists registros_fc_tipo_check;
alter table public.registros_fc add constraint registros_fc_tipo_check check (tipo in ('entrenamiento','partido'));
drop policy if exists fc_alumno_alta on public.registros_fc;
create policy fc_alumno_alta on public.registros_fc for insert to authenticated
  with check (alumno_id = (select public.mi_alumno_id()) and tipo = 'partido');
drop policy if exists fc_alumno_borra on public.registros_fc;
create policy fc_alumno_borra on public.registros_fc for delete to authenticated
  using (alumno_id = (select public.mi_alumno_id()) and tipo = 'partido');

-- 2. Cada alumno puede leer los emails que se le han enviado
drop policy if exists emails_propios on public.emails;
create policy emails_propios on public.emails for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

-- 3. Partidos y juegos tácticos; el alumno puede registrar los suyos
alter table public.partidos drop constraint if exists partidos_formato_check;
alter table public.partidos add constraint partidos_formato_check check (formato in ('3sets','1set','libre','tactico'));
alter table public.partidos add column if not exists creado_por uuid default auth.uid() references auth.users(id) on delete set null;
create index if not exists partidos_creado_por_idx on public.partidos (creado_por);
drop policy if exists partidos_alumno_lee on public.partidos;
create policy partidos_alumno_lee on public.partidos for select to authenticated using (creado_por = (select auth.uid()));
drop policy if exists partidos_alumno_alta on public.partidos;
create policy partidos_alumno_alta on public.partidos for insert to authenticated
  with check (creado_por = (select auth.uid()) and (select public.mi_alumno_id()) is not null);
drop policy if exists partidos_alumno_cambia on public.partidos;
create policy partidos_alumno_cambia on public.partidos for update to authenticated
  using (creado_por = (select auth.uid())) with check (creado_por = (select auth.uid()));
drop policy if exists partidos_alumno_borra on public.partidos;
create policy partidos_alumno_borra on public.partidos for delete to authenticated using (creado_por = (select auth.uid()));

alter table public.stats_jugador add column if not exists modo text not null default 'partido';
drop policy if exists stats_alumno_escribe on public.stats_jugador;
create policy stats_alumno_escribe on public.stats_jugador for insert to authenticated
  with check (exists (select 1 from public.partidos p where p.id = partido_id and p.creado_por = (select auth.uid())));
drop policy if exists stats_alumno_borra on public.stats_jugador;
create policy stats_alumno_borra on public.stats_jugador for delete to authenticated
  using (exists (select 1 from public.partidos p where p.id = partido_id and p.creado_por = (select auth.uid())));

-- 4. Compañeros para elegir jugadores al registrar un partido (solo nombre corto)
create or replace function public.companeros() returns table (id uuid, nombre text, grupo_id uuid)
language sql stable security definer set search_path = '' as
$$
  select a.id,
         split_part(a.nombre, ' ', 1) || coalesce(' ' || nullif(left(split_part(a.nombre, ' ', 2), 1), '') || '.', ''),
         a.grupo_id
  from public.alumnos a
  where a.activo and (select public.mi_alumno_id()) is not null
  order by a.nombre
$$;
revoke all on function public.companeros() from public, anon;
grant execute on function public.companeros() to authenticated;

-- 5. Comparativa anónima: tipo de sesión y modo de juego
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
                            'pct_juegos_saque', s.pct_juegos_saque, 'pct_oro_resto', s.pct_oro_resto))
                          from public.stats_jugador s join otros o on o.id = s.alumno_id, aj where s.fecha >= aj.inicio_temporada), '[]'::jsonb)
  ) end
$$;
revoke all on function public.comparativa() from public, anon;
grant execute on function public.comparativa() to authenticated;
