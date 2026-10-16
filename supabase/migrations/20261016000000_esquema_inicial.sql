-- Bandeja · esquema de base de datos para Supabase (Postgres)
-- Basado en las hojas GESTIÓN DE PAGOS 24/25 y GESTIÓN ESCUELA.
-- Ejecutar en Supabase > SQL Editor.

create extension if not exists pgcrypto;

-- ---------- Catálogo ----------
create table tarifas (
  id text primary key,                 -- T1, T2, T3...
  nombre text not null,
  alumnos_por_pista int not null,
  horas numeric(3,1) not null,
  precio_mes numeric(6,2) not null,    -- bono 4 clases
  precio_trimestre numeric(6,2) not null -- bono 10 clases
);

create table grupos (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  dia_semana int not null check (dia_semana between 1 and 7),
  hora_inicio time not null,
  hora_fin time not null,
  tarifa_id text references tarifas(id),
  nivel text
);

-- ---------- Personas ----------
create table alumnos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),          -- se rellena cuando el alumno activa su acceso
  nombre text not null,
  email text not null,
  telefono text,
  fecha_nacimiento date,
  sexo text check (sexo in ('F','M')),
  peso_kg numeric(5,1),
  fc_max_medida int,                               -- si se conoce, sustituye a la teórica (220 - edad)
  grupo_id uuid references grupos(id),
  tutor_nombre text,                               -- obligatorio para menores
  codigo_acceso text unique not null default upper('PD-' || substr(md5(random()::text), 1, 6)),
  consentimiento_salud boolean not null default false,  -- RGPD art. 9: datos de FC son datos de salud
  consentimiento_imagen boolean not null default false,
  clases_iniciales int not null default 0,
  activo boolean not null default true,
  creado timestamptz not null default now()
);

-- ---------- Pagos y bonos ----------
create table pagos (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references alumnos(id) on delete cascade,
  fecha date not null default current_date,
  metodo text not null check (metodo in ('Efectivo','Transferencia','Bizum','Tarjeta')),
  concepto text not null,                          -- Bono mensual, trimestral, clase suelta, material
  clases int not null default 0,
  importe numeric(7,2) not null,
  creado timestamptz not null default now()
);

create table sesiones (                            -- cada clase programada de un grupo
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references grupos(id) on delete cascade,
  fecha date not null,
  titulo text,
  contenidos text[] default '{}',
  unique (grupo_id, fecha)
);

create table asistencia (
  sesion_id uuid references sesiones(id) on delete cascade,
  alumno_id uuid references alumnos(id) on delete cascade,
  primary key (sesion_id, alumno_id)
);

create view saldo_alumnos as
select a.id as alumno_id,
       a.clases_iniciales + coalesce((select sum(p.clases) from pagos p where p.alumno_id = a.id), 0) as clases_pagadas,
       (select count(*) from asistencia s where s.alumno_id = a.id) as clases_recibidas,
       a.clases_iniciales + coalesce((select sum(p.clases) from pagos p where p.alumno_id = a.id), 0)
         - (select count(*) from asistencia s where s.alumno_id = a.id) as saldo
from alumnos a;

-- ---------- Frecuencia cardíaca ----------
create table registros_fc (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references alumnos(id) on delete cascade,
  sesion_id uuid references sesiones(id),
  fecha date not null,
  duracion_min int not null,
  fc_media int not null,
  fc_max int not null,
  zonas_min int[5] not null,                       -- minutos en Z1..Z5
  kcal int,
  etrimp int generated always as (zonas_min[1] + 2*zonas_min[2] + 3*zonas_min[3] + 4*zonas_min[4] + 5*zonas_min[5]) stored,
  sensor text,
  muestras jsonb                                    -- serie segundo a segundo (opcional) e intervalos RR
);

-- ---------- Condición física ----------
create table tests_fisicos (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references alumnos(id) on delete cascade,
  temporada text not null,                         -- '26/27'
  periodo text not null check (periodo in ('Octubre','Diciembre','Abril','Junio')),
  fecha date,
  peso numeric(5,1), agilidad_1 numeric(5,2), agilidad_2 numeric(5,2), agilidad_3 numeric(5,2),
  precision int, rpe int,
  unique (alumno_id, temporada, periodo)
);

-- ---------- Interpretaciones de IA y emails ----------
create table informes_ia (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references alumnos(id) on delete cascade,
  generado timestamptz not null default now(),
  texto text not null,
  revisado_por_entrenador boolean not null default false
);

create table emails (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid references alumnos(id) on delete set null,
  tipo text not null check (tipo in ('confirmacion','aviso','bienvenida')),
  asunto text not null,
  cuerpo text not null,
  estado text not null default 'en_cola' check (estado in ('en_cola','enviado','error')),
  creado timestamptz not null default now(),
  enviado timestamptz
);

-- ---------- Seguridad: cada alumno solo ve lo suyo ----------
create table admins (user_id uuid primary key references auth.users(id));
create or replace function es_admin() returns boolean language sql stable as
$$ select exists (select 1 from admins where user_id = auth.uid()) $$;

alter table alumnos enable row level security;
alter table pagos enable row level security;
alter table asistencia enable row level security;
alter table registros_fc enable row level security;
alter table tests_fisicos enable row level security;
alter table informes_ia enable row level security;
alter table emails enable row level security;
alter table sesiones enable row level security;
alter table grupos enable row level security;
alter table tarifas enable row level security;

create policy admin_todo_alumnos on alumnos for all using (es_admin()) with check (es_admin());
create policy alumno_ve_su_ficha on alumnos for select using (user_id = auth.uid());

create policy admin_todo_pagos on pagos for all using (es_admin()) with check (es_admin());
create policy alumno_ve_sus_pagos on pagos for select using (alumno_id in (select id from alumnos where user_id = auth.uid()));

create policy admin_todo_asis on asistencia for all using (es_admin()) with check (es_admin());
create policy alumno_ve_su_asis on asistencia for select using (alumno_id in (select id from alumnos where user_id = auth.uid()));

create policy admin_todo_fc on registros_fc for all using (es_admin()) with check (es_admin());
create policy alumno_ve_su_fc on registros_fc for select using (alumno_id in (select id from alumnos where user_id = auth.uid()));

create policy admin_todo_tests on tests_fisicos for all using (es_admin()) with check (es_admin());
-- Los alumnos ven todos los tests para comparar con su grupo, pero la app solo muestra medias, nunca nombres ajenos.
-- Si prefieres más privacidad, sustituye por una vista con medias agregadas.
create policy alumno_ve_tests on tests_fisicos for select using (auth.uid() is not null);

create policy admin_todo_ia on informes_ia for all using (es_admin()) with check (es_admin());
create policy alumno_ve_su_ia on informes_ia for select using (revisado_por_entrenador and alumno_id in (select id from alumnos where user_id = auth.uid()));

create policy admin_todo_emails on emails for all using (es_admin()) with check (es_admin());

create policy lectura_sesiones on sesiones for select using (auth.uid() is not null);
create policy admin_sesiones on sesiones for all using (es_admin()) with check (es_admin());
create policy lectura_grupos on grupos for select using (auth.uid() is not null);
create policy admin_grupos on grupos for all using (es_admin()) with check (es_admin());
create policy lectura_tarifas on tarifas for select using (true);
create policy admin_tarifas on tarifas for all using (es_admin()) with check (es_admin());

-- ---------- Datos iniciales (hoja TARIFAS) ----------
insert into tarifas values
  ('T1', 'Grupo 4 · 1,5 h', 4, 1.5, 40, 95),
  ('T2', 'Pareja · 1 h',    2, 1.0, 60, 140),
  ('T3', 'Grupo 4 · 1 h',   4, 1.0, 30, 65);
