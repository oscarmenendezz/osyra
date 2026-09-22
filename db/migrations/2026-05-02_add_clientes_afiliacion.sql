begin;

create table if not exists public.clientes_afiliados (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  dni_cif text not null,
  numero_afiliado text not null unique
    default ('CL-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8))),
  qr_auth_code text unique,
  zip_recuperacion text,
  imagen_perfil_url text,
  visitas_validas integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint clientes_afiliados_dni_cif_unique unique (dni_cif),
  constraint clientes_afiliados_visitas_validas_check check (visitas_validas >= 0 and visitas_validas <= 5)
);

create index if not exists idx_clientes_afiliados_numero
  on public.clientes_afiliados (numero_afiliado);

create index if not exists idx_clientes_afiliados_dni_cif
  on public.clientes_afiliados (dni_cif);

alter table public.pedidos
  add column if not exists cliente_afiliado_id uuid,
  add column if not exists afiliado_numero text,
  add column if not exists subtotal numeric(10,2),
  add column if not exists descuento_aplicado numeric(10,2),
  add column if not exists descuento_porcentaje numeric(5,2);

alter table public.pedidos
  drop constraint if exists pedidos_cliente_afiliado_fk;

alter table public.pedidos
  add constraint pedidos_cliente_afiliado_fk
  foreign key (cliente_afiliado_id)
  references public.clientes_afiliados(id)
  on delete set null;

update public.pedidos
set subtotal = coalesce(subtotal, total),
    descuento_aplicado = coalesce(descuento_aplicado, 0),
    descuento_porcentaje = coalesce(descuento_porcentaje, 0)
where subtotal is null
   or descuento_aplicado is null
   or descuento_porcentaje is null;

alter table public.pedidos
  alter column subtotal set default 0,
  alter column subtotal set not null,
  alter column descuento_aplicado set default 0,
  alter column descuento_aplicado set not null,
  alter column descuento_porcentaje set default 0,
  alter column descuento_porcentaje set not null;

alter table public.clientes_afiliados enable row level security;

drop policy if exists clientes_afiliados_select on public.clientes_afiliados;
drop policy if exists clientes_afiliados_insert on public.clientes_afiliados;
drop policy if exists clientes_afiliados_update on public.clientes_afiliados;
drop policy if exists clientes_afiliados_delete on public.clientes_afiliados;

create policy clientes_afiliados_select
  on public.clientes_afiliados
  for select
  to anon, authenticated
  using (true);

create policy clientes_afiliados_insert
  on public.clientes_afiliados
  for insert
  to anon, authenticated
  with check (true);

create policy clientes_afiliados_update
  on public.clientes_afiliados
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy clientes_afiliados_delete
  on public.clientes_afiliados
  for delete
  to anon, authenticated
  using (true);

insert into public.clientes_afiliados (
  nombre,
  dni_cif,
  numero_afiliado,
  qr_auth_code,
  zip_recuperacion,
  imagen_perfil_url,
  visitas_validas
)
values
  (
    'Oscar',
    '12345678Z',
    'CL-OSCAR01',
    'QR-CL-OSCAR01',
    '28001',
    null,
    0
  ),
  (
    'Emma',
    '87654321X',
    'CL-EMMA01',
    'QR-CL-EMMA01',
    '46001',
    null,
    0
  )
on conflict do nothing;

commit;
