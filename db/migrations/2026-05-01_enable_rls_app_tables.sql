begin;

-- Permisos de tabla para que las policies puedan aplicarse con anon/authenticated.
grant select, insert, update, delete on table public.mesas to anon, authenticated;
grant select, insert, update, delete on table public.productos to anon, authenticated;
grant select, insert, update, delete on table public.pedidos to anon, authenticated;
grant select, insert, update, delete on table public.lineas_pedido to anon, authenticated;
grant select, insert, update, delete on table public.control_copeo to anon, authenticated;

-- Activar RLS en todas las tablas de la app.
alter table public.mesas enable row level security;
alter table public.productos enable row level security;
alter table public.pedidos enable row level security;
alter table public.lineas_pedido enable row level security;
alter table public.control_copeo enable row level security;

-- Limpiar policies previas (idempotente).
drop policy if exists mesas_select on public.mesas;
drop policy if exists mesas_insert on public.mesas;
drop policy if exists mesas_update on public.mesas;
drop policy if exists mesas_delete on public.mesas;

drop policy if exists productos_select on public.productos;
drop policy if exists productos_insert on public.productos;
drop policy if exists productos_update on public.productos;
drop policy if exists productos_delete on public.productos;

drop policy if exists pedidos_select on public.pedidos;
drop policy if exists pedidos_insert on public.pedidos;
drop policy if exists pedidos_update on public.pedidos;
drop policy if exists pedidos_delete on public.pedidos;

drop policy if exists lineas_pedido_select on public.lineas_pedido;
drop policy if exists lineas_pedido_insert on public.lineas_pedido;
drop policy if exists lineas_pedido_update on public.lineas_pedido;
drop policy if exists lineas_pedido_delete on public.lineas_pedido;

drop policy if exists control_copeo_select on public.control_copeo;
drop policy if exists control_copeo_insert on public.control_copeo;
drop policy if exists control_copeo_update on public.control_copeo;
drop policy if exists control_copeo_delete on public.control_copeo;

-- MESA policies
create policy mesas_select
  on public.mesas
  for select
  to anon, authenticated
  using (true);

create policy mesas_insert
  on public.mesas
  for insert
  to anon, authenticated
  with check (true);

create policy mesas_update
  on public.mesas
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy mesas_delete
  on public.mesas
  for delete
  to anon, authenticated
  using (true);

-- PRODUCTOS policies
create policy productos_select
  on public.productos
  for select
  to anon, authenticated
  using (true);

create policy productos_insert
  on public.productos
  for insert
  to anon, authenticated
  with check (true);

create policy productos_update
  on public.productos
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy productos_delete
  on public.productos
  for delete
  to anon, authenticated
  using (true);

-- PEDIDOS policies
create policy pedidos_select
  on public.pedidos
  for select
  to anon, authenticated
  using (true);

create policy pedidos_insert
  on public.pedidos
  for insert
  to anon, authenticated
  with check (true);

create policy pedidos_update
  on public.pedidos
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy pedidos_delete
  on public.pedidos
  for delete
  to anon, authenticated
  using (true);

-- LINEAS PEDIDO policies
create policy lineas_pedido_select
  on public.lineas_pedido
  for select
  to anon, authenticated
  using (true);

create policy lineas_pedido_insert
  on public.lineas_pedido
  for insert
  to anon, authenticated
  with check (true);

create policy lineas_pedido_update
  on public.lineas_pedido
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy lineas_pedido_delete
  on public.lineas_pedido
  for delete
  to anon, authenticated
  using (true);

-- CONTROL COPEO policies
create policy control_copeo_select
  on public.control_copeo
  for select
  to anon, authenticated
  using (true);

create policy control_copeo_insert
  on public.control_copeo
  for insert
  to anon, authenticated
  with check (true);

create policy control_copeo_update
  on public.control_copeo
  for update
  to anon, authenticated
  using (true)
  with check (true);

create policy control_copeo_delete
  on public.control_copeo
  for delete
  to anon, authenticated
  using (true);

commit;
