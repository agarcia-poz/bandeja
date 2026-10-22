-- Precio editable de la clase suelta en cada tarifa
alter table public.tarifas add column if not exists precio_suelta numeric(6,2);
update public.tarifas set precio_suelta = round(precio_mes / 4 + 3) where precio_suelta is null;
