begin;

alter table public.productos
  add column if not exists stock integer default 0,
  add column if not exists stock_minimo integer default 0;

update public.productos
set stock = coalesce(stock, 0),
    stock_minimo = coalesce(stock_minimo, 0)
where stock is null
   or stock_minimo is null;

alter table public.productos
  alter column stock set default 0,
  alter column stock set not null,
  alter column stock_minimo set default 0,
  alter column stock_minimo set not null;

alter table public.productos
  drop constraint if exists productos_stock_check,
  drop constraint if exists productos_stock_minimo_check;

alter table public.productos
  add constraint productos_stock_check check (stock >= 0),
  add constraint productos_stock_minimo_check check (stock_minimo >= 0);

commit;
