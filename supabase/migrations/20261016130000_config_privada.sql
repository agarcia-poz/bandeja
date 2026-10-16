-- Configuración privada que solo leen las funciones del servidor (clave de servicio).
-- Los valores reales se insertan a mano en Supabase; no se guardan en el repositorio.
create table public.config_privada (
  clave text primary key,
  valor text not null
);
alter table public.config_privada enable row level security;
revoke all on public.config_privada from anon, authenticated;
comment on table public.config_privada is 'Solo accesible con la clave de servicio (funciones). Sin políticas a propósito.';
-- insert into public.config_privada (clave, valor) values ('APPS_SCRIPT_URL', '...'), ('APPS_SCRIPT_SECRETO', '...');
