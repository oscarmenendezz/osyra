begin;

create table if not exists public.control_copeo (
  copa_producto_id uuid primary key references public.productos(id) on delete cascade,
  copas_pendientes integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint control_copeo_pendientes_check check (copas_pendientes >= 0)
);

alter table public.control_copeo enable row level security;

grant select, insert, update, delete on table public.control_copeo to anon, authenticated;

drop policy if exists control_copeo_select on public.control_copeo;
drop policy if exists control_copeo_insert on public.control_copeo;
drop policy if exists control_copeo_update on public.control_copeo;
drop policy if exists control_copeo_delete on public.control_copeo;

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
