# Osyra TPV

Aplicacion Flutter para gestion de TPV, stock e informes con backend en Supabase.

## Estado Del Proyecto

Actualizado: 2026-05-02

Estado general: en desarrollo activo, con flujo principal operativo.

## Funcionalidades Implementadas

### TPV

- Gestion de mesas y apertura/cierre de pedidos.
- Renombrado temporal de mesa por cliente y restauracion al cerrar.
- Alta de lineas de pedido con control de stock.
- Modo de cajas de botellas (3, 6, 12) con proteccion ante taps concurrentes.
- Cobro con descuento de afiliacion cuando corresponde.

### Stock

- Gestion de productos con categoria y subcategoria.
- Soporte de denominacion de origen para botellas.
- Seguimiento de stock minimo y stock actual.

### Informes

- Informes por periodo: diario, semanal, mensual, anual y rango.
- Graficas por periodo y desglose por tickets.
- Exclusion de tickets de 0 EUR en consultas de informe.
- Exportacion a Excel y PDF con filtros por tipo de producto.
- Impresion de ticket individual y de todos los tickets.
- Fallback de impresion a guardado en Descargas cuando el plugin no esta disponible.
- Informe personalizado por cliente afiliado (dentro de Informes):
	- Busqueda por numero de afiliado o DNI/CIF.
	- Rango de fechas independiente.
	- Resumen de pedidos, gastado, ahorrado y ticket medio.
	- Detalle ampliado por ticket con lineas de producto.
	- Impresion PDF del informe de cliente por rango.

### Afiliacion / Clientes

- Tabla `clientes_afiliados` con seeds iniciales (Oscar y Emma).
- Login de cliente afiliado en TPV por numero de afiliado o DNI/CIF (cualquiera de los dos).
- Acumulacion de visitas validas y reseteo al aplicar descuento.
- Alta de clientes desde modulo dedicado de Clientes con datos de contacto y direccion.
- Envio de correo automatico al dar de alta, incluyendo QR de autenticacion.

### UI

- Refresh visual general con paleta morada.
- Fondo con watermark usando logo corporativo.
- Splash inicial usando asset de logo en lugar de texto plano.

## Estructura Relevante

- `lib/pages/tpv_page.dart`: flujo de venta y cobro.
- `lib/pages/stock_page.dart`: gestion de inventario.
- `lib/pages/informes_page.dart`: analitica, exportaciones e impresion.
- `lib/services/pedido_service.dart`: consultas de tickets e informes.
- `lib/services/cliente_afiliado_service.dart`: busqueda y logica de afiliacion.
- `db/migrations/`: cambios de esquema y seeds.

## Dependencias Clave

- `supabase_flutter`
- `pdf`
- `printing`
- `excel`
- `path_provider`
- `google_fonts`

## Ejecucion Local

1. Instalar dependencias:

```bash
flutter pub get
```

2. Ejecutar app:

```bash
flutter run
```

3. Validar analisis estatico:

```bash
flutter analyze
```

## Base De Datos Y Migraciones

Migraciones relevantes ya creadas en `db/migrations`, incluyendo:

- soporte de stock y campos adicionales
- politicas RLS para tablas de app
- soporte de afiliacion y columnas de descuento en pedidos

Si un entorno nuevo no tiene el esquema actualizado, aplicar las migraciones pendientes antes de probar afiliacion e informes avanzados.

## Correo De Alta Con QR

El alta de cliente llama a una Edge Function de Supabase para enviar el correo de bienvenida con QR:

- `supabase/functions/send-cliente-afiliado-email/index.ts`

Configura estas variables en Supabase Secrets:

- `RESEND_API_KEY`
- `RESEND_FROM`

Notas:

- Sin `RESEND_API_KEY` no se enviara el correo.

## Correo De Informe Anual

Al exportar informes desde la pantalla de Informes, si el tipo seleccionado es anual, la app invoca la Edge Function:

- `supabase/functions/send-informe-anual-email/index.ts`

Secrets requeridos en Supabase:

- `RESEND_API_KEY`
- `RESEND_FROM`
- `REPORTS_TO_EMAIL` (correo destino del propietario para avisos de informe anual)

## Notas Tecnicas Recientes

- Se corrigio error de concurrencia al completar caja de 12 botellas.
- Se movio el informe de cliente desde TPV al modulo de Informes.
- Se amplio el detalle por pedido (lineas de productos) en UI y PDF.
- Se reforzo la inicializacion de listas de lineas para evitar null en runtime.

## Pendientes Sugeridos

- Exportacion Excel especifica del informe por cliente.
- Tests de integracion para flujo de afiliacion y descuento.
- QA E2E del flujo de impresion en Windows con y sin plugin activo.
