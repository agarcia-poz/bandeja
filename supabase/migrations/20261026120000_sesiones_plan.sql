-- Diseño de sesiones: fases, tareas, objetivos de carga y versiones por pista
alter table public.sesiones add column if not exists plan jsonb;
