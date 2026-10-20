-- Emails con diseño HTML propio (resumen de sesión) y datos de saque/sorteo/lados de cada partido.
alter table public.emails add column html text;
alter table public.emails drop constraint if exists emails_tipo_check;
alter table public.emails add constraint emails_tipo_check check (tipo in ('confirmacion','aviso','bienvenida','sesion'));
alter table public.partidos add column extra jsonb not null default '{}';
