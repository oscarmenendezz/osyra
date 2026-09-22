begin;

-- Seed de tickets realistas para Informes:
-- - Crea actividad en algunos meses y deja otros vacios
-- - Genera dos anos: ano actual y ano anterior
-- - No sobrescribe datos existentes, solo completa hasta un objetivo
-- - Usa productos y mesas ya existentes

do $$
declare
  v_current_year int := extract(year from now())::int;
  v_current_month int := extract(month from now())::int;
  v_year int;
  v_month int;
  v_existing_closed int;
  v_target_year int;
  v_target_month int;
  v_to_create_month int;
  v_jitter numeric;

  v_pedido_id uuid;
  v_mesa_id uuid;
  v_producto_id uuid;
  v_tipo text;
  v_precio numeric;

  v_first_day date;
  v_last_day date;
  v_fecha timestamp;
  v_pick_day int;
  v_try_weekend int;
  v_pick_hour int;
  v_pick_minute int;

  v_attempt int;
  v_line_idx int;
  v_line_count int;
  v_line_qty int;
  v_total numeric;

  v_mesas_count int;
  v_productos_count int;
begin
  select count(*) into v_mesas_count from public.mesas;
  select count(*) into v_productos_count
  from public.productos
  where tipo in ('botella', 'conserva', 'tapa', 'copa')
    and coalesce(precio, 0) > 0;

  if v_mesas_count = 0 then
    raise notice 'Seed omitido: no hay mesas en public.mesas';
    return;
  end if;

  if v_productos_count < 10 then
    raise notice 'Seed omitido: pocos productos validos (%). Minimo recomendado: 10', v_productos_count;
    return;
  end if;

  -- Generamos para ano anterior y ano actual.
  foreach v_year in array array[v_current_year - 1, v_current_year]
  loop
    select count(*) into v_existing_closed
    from public.pedidos
    where estado = 'cerrado'
      and fecha >= make_date(v_year, 1, 1)
      and fecha < make_date(v_year + 1, 1, 1)
      and coalesce(total, 0) > 0;

    -- Si ya hay suficientes tickets cerrados, no forzamos mas datos.
    if v_existing_closed >= 180 then
      raise notice 'Ano % ya tiene % tickets cerrados, se omite generacion', v_year, v_existing_closed;
      continue;
    end if;

    for v_month in 1..12
    loop
      -- Meses vacios intencionales para que en anual haya huecos reales.
      if v_month in (3, 6, 9, 11) then
        continue;
      end if;

      -- Para el ano actual, no crear tickets en meses futuros.
      if v_year = v_current_year and v_month > v_current_month then
        continue;
      end if;

      -- Volumen base por mes (estacionalidad hosteleria simulada).
      v_target_month := case v_month
        when 1 then 24
        when 2 then 20
        when 4 then 22
        when 5 then 28
        when 7 then 36
        when 8 then 42
        when 10 then 30
        when 12 then 48
        else 0
      end;

      -- Ano actual mas comedido (YTD), ano anterior completo.
      if v_year = v_current_year then
        v_target_month := greatest(6, floor(v_target_month * 0.45)::int);
      end if;

      -- Variacion +/-20% para no parecer sintetico.
      v_jitter := 0.8 + (random() * 0.4);
      v_target_month := greatest(0, floor(v_target_month * v_jitter)::int);

      if v_target_month = 0 then
        continue;
      end if;

      -- Si ya hay tickets en ese mes, solo completamos hasta objetivo.
      select count(*) into v_existing_closed
      from public.pedidos
      where estado = 'cerrado'
        and fecha >= make_date(v_year, v_month, 1)
        and fecha < (make_date(v_year, v_month, 1) + interval '1 month');

      v_to_create_month := greatest(0, v_target_month - v_existing_closed);
      if v_to_create_month = 0 then
        continue;
      end if;

      v_first_day := make_date(v_year, v_month, 1);
      v_last_day := (make_date(v_year, v_month, 1) + interval '1 month - 1 day')::date;

      for v_attempt in 1..v_to_create_month
      loop
        -- Mesa aleatoria existente.
        select id into v_mesa_id
        from public.mesas
        order by random()
        limit 1;

        -- Fecha: mas probabilidad en viernes/sabado/domingo,
        -- y horarios de comida/cena.
        if random() < 0.62 then
          for v_try_weekend in 1..8
          loop
            v_pick_day := 1 + floor(random() * extract(day from v_last_day))::int;
            exit when extract(isodow from make_date(v_year, v_month, v_pick_day)) in (5, 6, 7);
          end loop;
        else
          v_pick_day := 1 + floor(random() * extract(day from v_last_day))::int;
        end if;

        if random() < 0.58 then
          v_pick_hour := 13 + floor(random() * 4)::int; -- 13:00-16:59
        else
          v_pick_hour := 20 + floor(random() * 4)::int; -- 20:00-23:59
        end if;
        v_pick_minute := floor(random() * 60)::int;

        v_fecha := make_timestamp(v_year, v_month, v_pick_day, v_pick_hour, v_pick_minute, 0);

        insert into public.pedidos (mesa_id, estado, fecha, total)
        values (v_mesa_id, 'cerrado', v_fecha, 0)
        returning id into v_pedido_id;

        v_line_count := 2 + floor(random() * 5)::int; -- 2..6 lineas
        v_total := 0;

        for v_line_idx in 1..v_line_count
        loop
          select id, tipo, precio
            into v_producto_id, v_tipo, v_precio
          from public.productos
          where tipo in ('botella', 'conserva', 'tapa', 'copa')
            and coalesce(precio, 0) > 0
          order by random()
          limit 1;

          if v_producto_id is null then
            continue;
          end if;

          v_line_qty := case
            when v_tipo = 'copa' then 1 + floor(random() * 3)::int      -- 1..3
            when v_tipo = 'botella' then 1 + floor(random() * 2)::int   -- 1..2
            else 1 + floor(random() * 4)::int                            -- 1..4
          end;

          insert into public.lineas_pedido (pedido_id, producto_id, cantidad, precio_unitario)
          values (v_pedido_id, v_producto_id, v_line_qty, round(v_precio::numeric, 2));

          v_total := v_total + (v_line_qty * round(v_precio::numeric, 2));
        end loop;

        -- Aseguramos minimo > 0 para que aparezca en informes.
        if v_total <= 0 then
          delete from public.lineas_pedido where pedido_id = v_pedido_id;
          delete from public.pedidos where id = v_pedido_id;
        else
          update public.pedidos
          set total = round(v_total::numeric, 2)
          where id = v_pedido_id;
        end if;
      end loop;
    end loop;
  end loop;
end
$$;

commit;
