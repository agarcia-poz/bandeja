-- Cobro automático de la clase al terminar y aviso de pago una hora antes
alter table public.sesiones add column if not exists cerrada boolean not null default false;
alter table public.sesiones add column if not exists avisos_enviados boolean not null default false;
alter table public.ajustes add column if not exists auto_desde date;
update public.ajustes set auto_desde = coalesce(auto_desde, date '2026-10-27') where id = 1;

-- Secreto de la tarea programada (solo lo leen las funciones del servidor)
insert into public.config_privada (clave, valor)
select 'CRON_TAREAS', encode(extensions.gen_random_bytes(24), 'hex')
where not exists (select 1 from public.config_privada where clave = 'CRON_TAREAS');

create extension if not exists pg_cron with schema pg_catalog;
select cron.unschedule(jobid) from cron.job where jobname = 'bandeja-automatico';
select cron.schedule('bandeja-automatico', '*/10 * * * *', $$
  select net.http_post(
    url := 'https://kbqlnomchinlshaxccpo.supabase.co/functions/v1/automatico',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', (select valor from public.config_privada where clave = 'CRON_TAREAS')),
    body := '{}'::jsonb,
    timeout_milliseconds := 30000)
$$);
