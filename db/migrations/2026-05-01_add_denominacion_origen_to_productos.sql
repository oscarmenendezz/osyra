begin;

alter table public.productos
  add column if not exists denominacion_origen text;

update public.productos
set denominacion_origen = nullif(trim(subcategoria), '')
where tipo = 'botella'
  and (denominacion_origen is null or trim(denominacion_origen) = '');

alter table public.productos
  drop constraint if exists productos_denominacion_origen_botella_check;

alter table public.productos
  add constraint productos_denominacion_origen_botella_check
  check (
    tipo <> 'botella'
    or (denominacion_origen is not null and trim(denominacion_origen) <> '')
  );

create index if not exists idx_productos_denominacion_origen
  on public.productos (denominacion_origen);

commit;
