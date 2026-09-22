begin;

-- 0) Garantizar columnas/tablas necesarias para copeo
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

create table if not exists public.control_copeo (
  copa_producto_id uuid primary key references public.productos(id) on delete cascade,
  copas_pendientes integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint control_copeo_pendientes_check check (copas_pendientes >= 0)
);

create index if not exists idx_productos_botella_origen
  on public.productos (botella_origen_id);

-- 1) Limpiar lineas de pedido asociadas a botellas, copas y conservas
-- (evita errores de foreign key al borrar productos)
delete from public.lineas_pedido lp
using public.productos p
where lp.producto_id = p.id
  and p.tipo in ('botella', 'copa', 'conserva');

-- 2) Borrar catalogo previo de botellas, copas y conservas
delete from public.productos
where tipo in ('botella', 'copa', 'conserva');

-- 3) Insertar catalogo real de vinos (botellas)
-- precio inventado entre 10.00 y 30.00 de forma determinista por nombre
with catalogo(nombre, denominacion_origen) as (
  values    ('12 LUNAS BLANCO', 'D.O. Somontano'),
    ('12 LUNAS GARNACHA', 'D.O. Somontano'),
    ('12 LUNAS ROSADO', 'D.O. Somontano'),
    ('12 LUNAS TINTO', 'D.O. Somontano'),
    ('ABADÍA DE SAN CAMPÍO', 'D.O. Rías Baixas'),
    ('AC', 'D.O. Rioja'),
    ('AC 5.5', 'D.O. Rioja'),
    ('ALTAMIMBRE 2016', 'D.O. Ribera del Duero'),
    ('ARENISCA', 'IGP Castilla y León'),
    ('ARTUKE', 'D.O. Rioja'),
    ('ASTRALES', 'D.O. Ribera del Duero'),
    ('ASTRALES CHRISTINA', 'D.O. Ribera del Duero'),
    ('AUREA', 'D.O. Bierzo'),
    ('BAELO 12', 'D.O. Tierra de Cádiz'),
    ('BAELO 24', 'D.O. Tierra de Cádiz'),
    ('BAYNOS', 'D.O. Castilla León'),
    ('BAYNOS BLANCO', 'D.O. Castilla León'),
    ('BENTO ORGÁNICO', 'D.O. Rueda'),
    ('BIGARDO', 'D.O. Toro'),
    ('BLANC DE BLANCS', 'D.O. Conca del Riu Anoia'),
    ('BLANCO', 'D.O. Rioja'),
    ('BLANQUITO', 'D.O. Rías Baixas'),
    ('BLUE CAP', 'D.O. Ribera del Duero'),
    ('BOCCA PAYASO', 'D.O. Ribera del Duero'),
    ('BOTÓN DE GALLO ROSADO', 'D.O. Rueda'),
    ('BOTÓN DE GALLO VERDEJO', 'D.O. Rueda'),
    ('BULERÍA BLANCO', 'D.O. Tierra de Cádiz'),
    ('BULERÍA TINTO', 'D.O. Tierra de Cádiz'),
    ('CALMA', 'D.O. Toro'),
    ('CALZADAS', 'D.O. Rioja'),
    ('CAMPANO', 'D.O. Tierra de Cádiz'),
    ('CANTAYANO', 'IGP Castilla y León'),
    ('CANTO DEL GRILLO', 'D.O. Somontano'),
    ('CARRAMIMBRE CRIANZA 2018', 'D.O. Ribera del Duero'),
    ('CARRAMIMBRE RESERVA', 'D.O. Ribera del Duero'),
    ('CARRAMIMBRE ROBLE 202', 'D.O. Ribera del Duero'),
    ('CARRAMIMBRE ROSADO 2022', 'D.O. Cigales'),
    ('CARRAMIMBRE VERDEJO 2020', 'D.O. Verdejo'),
    ('CARTAGO', 'D.O. Toro'),
    ('CITIUS', 'D.O. Castilla León'),
    ('COLLECTION', 'D.O. Ribera del Duero'),
    ('COLLECTION RUEDA', 'D.O. Rueda'),
    ('COORDENADAS', 'D.O. Rioja'),
    ('CRIANZA', 'D.O. Rioja'),
    ('CRIANZA RIBERA', 'D.O. Ribera del Ruedo'),
    ('CRIANZA RIOJA', 'D.O. Rioja'),
    ('DE LA FINCA', 'D.O. Conca del Riu Anoia'),
    ('DENIT', 'D.O. Conca del Riu Anoia'),
    ('DESPIERTA CABERNET SAUVIGNON', 'D.O. Castilla León'),
    ('DESPIERTA SAUVIGNON BLANC', 'D.O. Castilla León'),
    ('DESPIERTA TEMPRANILLO', 'D.O. Castilla León'),
    ('DESPIERTA VERDEJO', 'D.O. Castilla León'),
    ('DOS ALAS ROJAS', 'D.O. Ribera del Duero'),
    ('EL ESCOLLADERO', 'D.O. Rioja'),
    ('EL JARDÍN DE LA EMPERATRIZ BLANCO', 'D.O. Rioja'),
    ('EL JARDÍN DE LA EMPERATRIZ TINTO', 'D.O. Rioja'),
    ('EL PEDAL', 'D.O. Rioja'),
    ('EL SENTIDO DE LA VIDA', 'D.O. Jumilla'),
    ('EL TIEMPO QUE NOS UNE', 'D.O. Jumilla'),
    ('ETERNAUTA', 'D.O. Ribera del Duero'),
    ('FINCA DE LOS LOCOS', 'D.O. Rioja'),
    ('FINCA ESTARIJO', 'D.O. Rioja'),
    ('FINCA LA EMPERATRIZ BLANCO', 'D.O. Rioja'),
    ('FINCA LA EMPERATRIZ TINTO', 'D.O. Rioja'),
    ('FINO MICAELA', 'D.O. Jerez-Xérès-Sherry'),
    ('GARMÓN', 'D.O. Ribera del Duero'),
    ('GARNACHA PROMETIDA', 'D.O. Rioja'),
    ('GODELLO', 'D.O. Valdeorras'),
    ('GODELLO SOBRE LÍAS', 'D.O. Valdeorras'),
    ('GRACIANO', 'D.O. Rioja'),
    ('GRILLO', 'D.O. Somontano'),
    ('GRILLO SP', 'D.O. Somontano'),
    ('HOP HOP', 'D.O. Somontano'),
    ('INSPIRATION', 'D.O. Ribera del Duero'),
    ('JOVEN RIBERA', 'D.O. Ribera del Ruedo'),
    ('JOVEN RIOJA', 'D.O. Rioja'),
    ('LA BATALLA DE LA BARROSA', 'D.O. Tierra de Cádiz'),
    ('LA CALERA DEL ESCARAMUJO', 'D.O. Jumilla'),
    ('LA CONDENADA', 'D.O. Rioja'),
    ('LA MAR', 'D.O. Rías Baixas'),
    ('LA MARAGATA', 'D.O. Bierzo'),
    ('LA OTEA', 'IGP Castilla y León'),
    ('LA PROHIBICIÓN', 'D.O. Bierzo'),
    ('LA PROHIBICIÓN DULCE', 'D.O. Castilla y León'),
    ('LA PROHIBICIÓN PALOMINO FINO', 'D.O. Bierzo'),
    ('LA RABIA', 'D.O. Jumilla'),
    ('LA RODETTA CRIANZA', 'D.O. Rioja'),
    ('LA RODETTA VERDEJO', 'D.O. Rueda'),
    ('LA SERVIL', 'D.O. Jumilla'),
    ('LAS CENIZAS', 'D.O. Rioja'),
    ('LOS YESARES', 'D.O. Jumilla'),
    ('LUMA', 'D.O. Ribera del Duero'),
    ('LUNA BLANCA', 'D.O. Rueda'),
    ('MAJUELO DEL CHIRIVITERO', 'IGP Castilla y León'),
    ('MAJUELO EL ESPEJO', 'IGP Castilla y León'),
    ('MALDITO PARNÉ', 'D.O. Toro'),
    ('MANUEL', 'D.O. Conca del Riu Anoia'),
    ('MANZANILLA MICAELA', 'D.O. Manzanilla-Sanlúcar de Barrameda'),
    ('MAS DEL SERRAL', 'D.O. Conca del Riu Anoia'),
    ('MATAS ALTAS', 'D.O. Jumilla'),
    ('MAURO', 'D.O. Castilla León'),
    ('MAURO GODELLO', 'D.O. Castilla León'),
    ('MAURO VS', 'D.O. Castilla León'),
    ('MOMENTO', 'D.O. Rioja'),
    ('MOSCATEL GLORIA', 'D.O. Tierra de Cádiz'),
    ('PALO CORTADO MICAELA', 'D.O. Jerez-Xérès-Sherry'),
    ('PÁRPADOS', 'D.O. Ribera del Duero'),
    ('PASO LAS MAÑAS', 'D.O. Rioja'),
    ('PAVINA TINTO', 'D.O. Castilla León'),
    ('PELLEJO', 'D.O. Toro'),
    ('PETIT', 'D.O. Bierzo'),
    ('PIES NEGROS', 'D.O. Rioja'),
    ('PINOT NOIR', 'D.O. Castilla León'),
    ('PINOT NOIR ROSÉ', 'D.O. Castilla León'),
    ('PITTACUM', 'D.O. Bierzo'),
    ('PONTELLÓN', 'D.O. Rías Baixas'),
    ('PRIMA', 'D.O. Toro'),
    ('QS2', 'D.O. Castilla y León'),
    ('QUINTA SARDONIA', 'D.O. Castilla y León'),
    ('RAÚL CALVO JOVEN', 'D.O. Ribera del Duero'),
    ('RAÚL CALVO ROBLE', 'D.O. Ribera del Duero'),
    ('REMORDIMIENTO', 'D.O. Jumilla'),
    ('REMORDIMIENTO BLANCO', 'D.O. Jumilla'),
    ('RESERVA', 'D.O. Rioja'),
    ('RIBERA ROBLE', 'D.O. Ribera del Ruedo'),
    ('SAN ROMÁN', 'D.O. Toro'),
    ('SARDÓN', 'D.O. Castilla y León'),
    ('SATÉLITE', 'D.O. Toro'),
    ('SILGA', 'D.O. Rueda'),
    ('TARANTELO CHARDONNAY', 'D.O. Tierra de Cádiz'),
    ('TARANTELO TINTO', 'D.O. Tierra de Cádiz'),
    ('TERRAS GAUDA', 'D.O. Rías Baixas'),
    ('TERRAS GAUDA ETIQUETA NEGRA', 'D.O. Rías Baixas'),
    ('TERREUS', 'D.O. Castilla León'),
    ('TEXTURES DE PEDRA', 'D.O. Conca del Riu Anoia'),
    ('TINTO', 'D.O. Rioja'),
    ('TODO SOBRE MI', 'D.O. Jumilla'),
    ('TRASCUEVAS', 'D.O. Rioja'),
    ('VAL DE LA OSA', 'D.O. Bierzo'),
    ('VALEYO', 'D.O. Bierzo'),
    ('VERDEJO', 'D.O. Rueda'),
    ('VERDEJO RUEDA', 'D.O. Rueda'),
    ('VERMUT ARTESANO', 'D.O. Tierra de Cádiz'),
    ('XIXARITO AMONTILLADO', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO CREAM', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO FINO', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO MANZANILLA', 'D.O. Manzanilla-Sanlúcar de Barrameda'),
    ('XIXARITO MEDIUM', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO OLOROSO', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO PALO CORTADO', 'D.O. Jerez-Xérès-Sherry'),
    ('XIXARITO PEDRO XIMÉNEZ', 'D.O. Jerez-Xérès-Sherry')
), catalogo_limpio as (
  select distinct
    trim(nombre) as nombre,
    trim(denominacion_origen) as denominacion_origen
  from catalogo
  where trim(nombre) <> ''
)
insert into public.productos (
  nombre,
  precio,
  tipo,
  subcategoria,
  denominacion_origen,
  stock,
  stock_minimo
)
select
  nombre,
  round((10 + ((abs(hashtextextended(nombre, 0)) % 2001)::numeric / 100)), 2) as precio,
  'botella',
  denominacion_origen,
  denominacion_origen,
  10,
  0
from catalogo_limpio
order by nombre;

-- 4) Generar 2 vinos de copeo por cada D.O., enlazados a su botella origen
with botellas_por_do as (
  select
    id,
    nombre,
    precio,
    denominacion_origen,
    row_number() over (
      partition by denominacion_origen
      order by nombre asc
    ) as rn
  from public.productos
  where tipo = 'botella'
    and denominacion_origen is not null
), seleccion as (
  select *
  from botellas_por_do
  where rn <= 2
)
insert into public.productos (
  nombre,
  precio,
  tipo,
  subcategoria,
  denominacion_origen,
  botella_origen_id,
  copas_por_botella,
  stock,
  stock_minimo
)
select
  'Copa ' || nombre,
  round(greatest(2.80, least(7.50, (precio / 5.0) * 1.30)), 2) as precio_copa,
  'copa',
  denominacion_origen,
  denominacion_origen,
  id,
  5,
  10,
  0
from seleccion
order by denominacion_origen, nombre;

-- 5) Crear conservas (precios realistas de abaceria)
insert into public.productos (
  nombre,
  precio,
  tipo,
  subcategoria,
  stock,
  stock_minimo
)
values
  ('Mejillones en escabeche 8/12', 8.90, 'conserva', 'marisco', 10, 0),
  ('Mejillones en escabeche 4/6', 6.40, 'conserva', 'marisco', 10, 0),
  ('Anchoas del Cantabrico 00', 16.50, 'conserva', 'pescado', 10, 0),
  ('Sardinillas en aceite de oliva', 6.20, 'conserva', 'pescado', 10, 0),
  ('Ventresca de atun en aceite de oliva', 9.80, 'conserva', 'pescado', 10, 0),
  ('Lomo de atun rojo en aceite', 11.90, 'conserva', 'pescado', 10, 0),
  ('Berberechos al natural', 14.20, 'conserva', 'marisco', 10, 0),
  ('Navajas al natural', 10.70, 'conserva', 'marisco', 10, 0),
  ('Zamburinas en salsa de vieira', 8.30, 'conserva', 'marisco', 10, 0),
  ('Chipirones rellenos en su tinta', 7.10, 'conserva', 'marisco', 10, 0),
  ('Pulpo en aceite de oliva', 12.40, 'conserva', 'marisco', 10, 0),
  ('Caballa en aceite de oliva', 5.60, 'conserva', 'pescado', 10, 0),
  ('Melva canutera en aceite', 5.20, 'conserva', 'pescado', 10, 0),
  ('Bonito del norte en escabeche', 8.60, 'conserva', 'pescado', 10, 0),
  ('Pate de mejillon picante', 4.40, 'conserva', 'pate', 10, 0),
  ('Pate de centollo', 5.80, 'conserva', 'pate', 10, 0),
  ('Pimientos del piquillo confitados', 6.30, 'conserva', 'vegetal', 10, 0),
  ('Esparragos blancos extra', 7.90, 'conserva', 'vegetal', 10, 0),
  ('Corazones de alcachofa', 8.40, 'conserva', 'vegetal', 10, 0),
  ('Aceituna manzanilla aliñada', 3.90, 'conserva', 'encurtido', 10, 0),
  ('Aceituna gordal rellena', 4.60, 'conserva', 'encurtido', 10, 0),
  ('Pepinillos agridulces', 3.70, 'conserva', 'encurtido', 10, 0),
  ('Gilda tradicional (6 uds)', 6.80, 'conserva', 'encurtido', 10, 0),
  ('Gilda boqueron (6 uds)', 7.20, 'conserva', 'encurtido', 10, 0);

-- 6) Asegurar precio para cualquier producto existente sin precio
update public.productos
set precio = case
  when tipo = 'botella' then round((10 + ((abs(hashtextextended(nombre, 0)) % 2001)::numeric / 100)), 2)
  when tipo = 'copa' then round((2.50 + ((abs(hashtextextended(nombre, 0)) % 351)::numeric / 100)), 2)
  when tipo = 'conserva' then round((3.50 + ((abs(hashtextextended(nombre, 0)) % 851)::numeric / 100)), 2)
  else round((2.00 + ((abs(hashtextextended(nombre, 0)) % 1201)::numeric / 100)), 2)
end
where precio is null or precio <= 0;

-- 7) Stock inicial para todos los productos
update public.productos
set stock = 10;

-- 8) Verificaciones rapidas
-- select tipo, count(*) from public.productos group by tipo order by tipo;
-- select min(precio), max(precio) from public.productos where tipo = 'botella';
-- select denominacion_origen, count(*) from public.productos where tipo = 'copa' group by denominacion_origen order by denominacion_origen;

commit;
