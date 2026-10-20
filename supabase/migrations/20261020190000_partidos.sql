-- Partidos con marcador punto a punto y estadísticas por jugador.
-- Se retiran los tests de condición física.

create table public.partidos (
  id uuid primary key default gen_random_uuid(),
  fecha date not null default current_date,
  tipo text not null default 'clase' check (tipo in ('clase','partido')),
  grupo_id uuid references public.grupos(id) on delete set null,
  jugadores jsonb not null,                       -- [{id: uuid|null, nombre}] x4 (0-1 pareja 1, 2-3 pareja 2)
  alumnos uuid[] not null default '{}',           -- alumnos que aparecen, para la seguridad por filas
  formato text not null default '3sets' check (formato in ('3sets','1set','libre')),
  punto_oro boolean not null default true,
  saque_inicial int not null default 0 check (saque_inicial in (0,1)),
  eventos jsonb not null default '[]',            -- [{tipo:'w'|'e'|'p', j, g, par, t}]
  estado text not null default 'en_juego' check (estado in ('en_juego','terminado')),
  resultado text,
  creado timestamptz not null default now(),
  actualizado timestamptz not null default now()
);
create index on public.partidos (fecha);
create index on public.partidos using gin (alumnos);
create index on public.partidos (grupo_id);

create table public.stats_jugador (
  partido_id uuid not null references public.partidos(id) on delete cascade,
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  pareja int not null,
  fecha date not null,
  ganado boolean,
  enf int not null default 0, win int not null default 0,
  pct_enf numeric, pct_win numeric, g_enf text, g_win text,
  pct_oro numeric, pct_break numeric, ppj numeric, indice numeric,
  golpes_enf jsonb, golpes_win jsonb,
  primary key (partido_id, alumno_id)
);
create index on public.stats_jugador (alumno_id);

alter table public.partidos enable row level security;
alter table public.stats_jugador enable row level security;
create policy partidos_admin on public.partidos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy partidos_propios on public.partidos for select to authenticated using ((select public.mi_alumno_id()) = any(alumnos));
create policy stats_admin on public.stats_jugador for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy stats_propias on public.stats_jugador for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

-- Comparativa anónima: sesiones de FC y estadísticas de partidos del resto de alumnos.
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
                            'enf', s.enf, 'win', s.win, 'pct_enf', s.pct_enf, 'pct_win', s.pct_win, 'pct_oro', s.pct_oro, 'pct_break', s.pct_break, 'ppj', s.ppj, 'indice', s.indice))
                          from public.stats_jugador s join otros o on o.id = s.alumno_id, aj where s.fecha >= aj.inicio_temporada), '[]'::jsonb)
  ) end
$$;
revoke all on function public.comparativa() from public, anon;
grant execute on function public.comparativa() to authenticated;

-- La tabla tests_fisicos queda sin uso (se puede borrar con: drop table public.tests_fisicos;)
