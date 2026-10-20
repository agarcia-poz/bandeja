-- Alumnos fijos y relevos, estado de asistencia, ajustes manuales del bono y gastos de la escuela.

alter table public.alumnos add column modalidad text not null default 'fijo' check (modalidad in ('fijo','relevo'));

-- presente: vino · falta: no vino (a un fijo se le cobra igual) · cubierta: vino un relevo en su lugar (no se le cobra)
alter table public.asistencia add column estado text not null default 'presente' check (estado in ('presente','falta','cubierta'));
alter table public.asistencia add column cobra boolean not null default true;

create table public.ajustes_clases (
  id uuid primary key default gen_random_uuid(),
  alumno_id uuid not null references public.alumnos(id) on delete cascade,
  fecha date not null default current_date,
  clases int not null check (clases <> 0),          -- positivo: clases a su favor; negativo: clases que debe
  motivo text,
  creado timestamptz not null default now()
);
create index on public.ajustes_clases (alumno_id);

create table public.gastos (
  id uuid primary key default gen_random_uuid(),
  fecha date not null default current_date,
  concepto text not null,
  categoria text not null,
  importe numeric(8,2) not null check (importe >= 0),
  metodo text,
  notas text,
  creado timestamptz not null default now()
);
create index on public.gastos (fecha);

alter table public.ajustes_clases enable row level security;
alter table public.gastos enable row level security;
create policy ajustes_clases_admin on public.ajustes_clases for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
create policy ajustes_clases_propios on public.ajustes_clases for select to authenticated using (alumno_id = (select public.mi_alumno_id()));
create policy gastos_admin on public.gastos for all to authenticated using ((select public.es_admin())) with check ((select public.es_admin()));
