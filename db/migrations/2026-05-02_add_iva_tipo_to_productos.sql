begin;

alter table public.productos
  add column if not exists iva_tipo numeric(5,2) default 21;

update public.productos
set iva_tipo = 21
where iva_tipo is null;

alter table public.productos
  alter column iva_tipo set default 21,
  alter column iva_tipo set not null;

alter table public.productos
  drop constraint if exists productos_iva_tipo_check;

alter table public.productos
  add constraint productos_iva_tipo_check
  check (iva_tipo >= 0 and iva_tipo <= 100);

commit;
