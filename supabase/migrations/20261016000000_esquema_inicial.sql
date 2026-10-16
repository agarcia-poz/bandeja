-- Bandeja · esquema inicial (Supabase / Postgres)
-- Basado en las hojas GESTIÓN DE PAGOS 24/25 y GESTIÓN ESCUELA.

create extension if not exists pgcrypto;

-- =========================================================
-- Administración
-- =========================================================
create table public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;
create policy admin_se_ve on public.admins for select to authenticated using (user_id = (select auth.uid()));

create or replace function public.es_admin() returns boolean
language sql stable security definer set search_path = '' as
$$ select exists (select 1 from public.admins where user_id = (select auth.uid())) $$;

create table public.ajustes (
  id int primary key default 1 check (id = 1),
  escuela text not null default 'Escuela de Pádel AG',
  remitente text not null default 'escuelapadelag@gmail.com',
  umbral_aviso int not null default 1 check (umbral_aviso between 0 and 5),
  temporada text not null default '26/27',
  inicio_temporada date not null default '2026-09-14',
  envio_automatico boolean not null default true
);
insert into public.ajustes default values;
alter table public.ajustes enable row level security;
create policy ajustes_lectura on public.ajustes for select to authenticated using (true);
create policy ajustes_admin on public.ajustes for update to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

-- =========================================================
-- Catálogo
-- =========================================================
create table public.tarifas (
  id text primary key,
  nombre text not null,
  alumnos_por_pista int not null,
  horas numeric(3,1) not null,
  precio_mes numeric(6,2) not null,        -- bono 4 clases
  precio_trimestre numeric(6,2) not null   -- bono 10 clases
);
insert into public.tarifas values
  ('T1', 'Grupo 4 · 1,5 h', 4, 1.5, 40, 95),
  ('T2', 'Pareja · 1 h',    2, 1.0, 60, 140),
  ('T3', 'Grupo 4 · 1 h',   4, 1.0, 30, 65);

create table public.grupos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  dia_semana int not null check (dia_semana between 0 and 6),   -- 0 domingo … 6 sábado
  hora_inicio time not null,
  hora_fin time not null,
  tarifa_id text not null references public.tarifas(id),
  nivel text,
  activo boolean not null default true
);
create index on public.grupos (tarifa_id);

-- =========================================================
-- Alumnado
-- =========================================================
create table public.alumnos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users(id) on delete set null,
  nombre text not null,
  email text not null,
  telefono text,
  fecha_nacimiento date,
  sexo text not null default 'M' check (sexo in ('F','M')),
  peso_kg numeric(5,1),
  grupo_id uuid references public.grupos(id) on delete set null,
  tutor_nombre text,
  codigo_acceso text unique not null default ('PD-' || upper(substr(md5(gen_random_uuid()::text), 1, 5))),
  consentimiento_salud boolean not null default false,
  consentimiento_imagen boolean not null default false,
  clases_iniciales int not null default 0,
  activo boolean not null default true,
  creado timestamptz not null default now()
);
create index on public.alumnos (grupo_id);
create index on public.alumnos (lower(email));

-- =========================================================
-- Pagos, sesiones y asistencia
-- =========================================================
create table public.pagos (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  fecha date not null default current_date,
  metodo text not null check (metodo in ('Efectivo','Transferencia','Bizum','Tarjeta')),
  concepto text not null check (concepto in ('mes','tri','suelta','material')),
  clases int not null default 0,
  importe numeric(7,2) not null,
  creado timestamptz not null default now()
);
create index on public.pagos (alumno_id);

create table public.sesiones (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references public.grupos(id) on delete cascade,
  fecha date not null,
  titulo text,
  contenidos text[] not null default '{}',
  unique (grupo_id, fecha)
);

create table public.asistencia (
  sesion_id uuid references public.sesiones(id) on delete cascade,
  alumno_id uuid references public.alumnos(id) on delete cascade,
  primary key (sesion_id, alumno_id)
);
create index on public.asistencia (alumno_id);

create table public.avisos (               -- evita repetir el mismo aviso de pago
  alumno_id uuid references public.alumnos(id) on delete cascade,
  clases_recibidas int not null,
  creado timestamptz not null default now(),
  primary key (alumno_id, clases_recibidas)
);

-- =========================================================
-- Frecuencia cardíaca y condición física
-- =========================================================
create table public.registros_fc (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  fecha date not null,
  duracion_min int not null,
  fc_media int not null,
  fc_max int not null,
  zonas_min int[] not null check (array_length(zonas_min, 1) = 5),   -- Z1..Z5
  kcal int,
  sensor text,
  muestras jsonb,                                                    -- serie 1 Hz opcional
  creado timestamptz not null default now()
);
create index on public.registros_fc (alumno_id, fecha);

create table public.tests_fisicos (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  temporada text not null,
  periodo text not null check (periodo in ('Octubre','Diciembre','Abril','Junio')),
  fecha date,
  peso numeric(5,1), agilidad_1 numeric(5,2), agilidad_2 numeric(5,2), agilidad_3 numeric(5,2),
  precision int, rpe int,
  unique (alumno_id, temporada, periodo)
);

-- =========================================================
-- IA y emails
-- =========================================================
create table public.informes_ia (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  generado timestamptz not null default now(),
  texto text not null,
  publicado boolean not null default false
);
create index on public.informes_ia (alumno_id, generado desc);

create table public.emails (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid references public.alumnos(id) on delete set null,
  destinatario text not null,
  nombre_destinatario text,
  tipo text not null check (tipo in ('confirmacion','aviso','bienvenida')),
  asunto text not null,
  cuerpo text not null,
  estado text not null default 'en_cola' check (estado in ('en_cola','enviado','error')),
  error text,
  creado timestamptz not null default now(),
  enviado timestamptz
);
create index on public.emails (estado);
create index on public.emails (alumno_id);

-- =========================================================
-- Seguridad por filas
-- =========================================================
create or replace function public.mi_alumno_id() returns uuid
language sql stable security definer set search_path = '' as
$$ select id from public.alumnos where user_id = (select auth.uid()) $$;

alter table public.tarifas enable row level security;
alter table public.grupos enable row level security;
alter table public.alumnos enable row level security;
alter table public.pagos enable row level security;
alter table public.sesiones enable row level security;
alter table public.asistencia enable row level security;
alter table public.avisos enable row level security;
alter table public.registros_fc enable row level security;
alter table public.tests_fisicos enable row level security;
alter table public.informes_ia enable row level security;
alter table public.emails enable row level security;

create policy tarifas_lectura on public.tarifas for select using (true);
create policy tarifas_admin on public.tarifas for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

create policy grupos_lectura on public.grupos for select to authenticated using (true);
create policy grupos_admin on public.grupos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

create policy sesiones_lectura on public.sesiones for select to authenticated using (true);
create policy sesiones_admin on public.sesiones for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

create policy alumnos_admin on public.alumnos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy alumnos_propio on public.alumnos for select to authenticated using (user_id = (select auth.uid()));

create policy pagos_admin on public.pagos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy pagos_propio on public.pagos for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

create policy asistencia_admin on public.asistencia for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy asistencia_propia on public.asistencia for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

create policy avisos_admin on public.avisos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

create policy fc_admin on public.registros_fc for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy fc_propio on public.registros_fc for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

create policy tests_admin on public.tests_fisicos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy tests_propio on public.tests_fisicos for select to authenticated using (alumno_id = (select public.mi_alumno_id()));

create policy ia_admin on public.informes_ia for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy ia_propio on public.informes_ia for select to authenticated using (publicado and alumno_id = (select public.mi_alumno_id()));

create policy emails_admin on public.emails for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));

-- =========================================================
-- Comparativa anónima para el portal del alumno
-- Devuelve los datos de la temporada de los demás alumnos sin nombre ni contacto,
-- identificados con una clave opaca, para calcular medias de grupo y de escuela.
-- =========================================================
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
    'tests', coalesce((select jsonb_agg(jsonb_build_object('k', o.k, 'periodo', t.periodo, 'ag1', t.agilidad_1, 'ag2', t.agilidad_2, 'ag3', t.agilidad_3, 'precision', t.precision))
                       from public.tests_fisicos t join otros o on o.id = t.alumno_id, aj where t.temporada = aj.temporada), '[]'::jsonb)
  ) end
$$;
revoke all on function public.comparativa() from public, anon;
grant execute on function public.comparativa() to authenticated;
revoke all on function public.es_admin() from public, anon;
grant execute on function public.es_admin() to authenticated;
revoke all on function public.mi_alumno_id() from public, anon;
grant execute on function public.mi_alumno_id() to authenticated;
