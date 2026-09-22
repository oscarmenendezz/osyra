begin;

alter table public.productos
  add column if not exists botella_origen_id uuid,
  add column if not exists copas_por_botella integer not null default 5;

alter table public.productos
  drop constraint if exists productos_botella_origen_fk;

alter table public.productos
  add constraint productos_botella_origen_fk
  foreign key (botella_origen_id)
  references public.productos(id)
  on delete set null;

alter table public.productos
  drop constraint if exists productos_copas_por_botella_check;

alter table public.productos
  add constraint productos_copas_por_botella_check
  check (copas_por_botella >= 1 and copas_por_botella <= 20);

alter table public.productos
  drop constraint if exists productos_copa_botella_origen_check;

alter table public.productos
  add constraint productos_copa_botella_origen_check
  check (
    tipo <> 'copa'
    or botella_origen_id is not null
  );

create table if not exists public.control_copeo (
  copa_producto_id uuid primary key references public.productos(id) on delete cascade,
  copas_pendientes integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint control_copeo_pendientes_check check (copas_pendientes >= 0)
);

create index if not exists idx_productos_botella_origen
  on public.productos (botella_origen_id);

commit;
