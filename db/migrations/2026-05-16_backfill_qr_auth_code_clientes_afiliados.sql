begin;

update public.clientes_afiliados
set qr_auth_code = 'QR-' || upper(substr(md5(gen_random_uuid()::text || clock_timestamp()::text), 1, 12))
where qr_auth_code is null
   or btrim(qr_auth_code) = '';

alter table public.clientes_afiliados
  alter column qr_auth_code set not null;

commit;
