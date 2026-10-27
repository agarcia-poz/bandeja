-- Cambios de calendario por grupo: clases movidas, anuladas y extra
alter table public.grupos add column if not exists calendario jsonb;
