begin;

alter table public.clientes_afiliados
  add column if not exists direccion text,
  add column if not exists codigo_postal text,
  add column if not exists localidad text,
  add column if not exists telefono text,
  add column if not exists email text;

create index if not exists idx_clientes_afiliados_email
  on public.clientes_afiliados (email);

create index if not exists idx_clientes_afiliados_telefono
  on public.clientes_afiliados (telefono);

commit;
