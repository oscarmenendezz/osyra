# Pruebas del proyecto Osyra

Este documento resume las pruebas automatizadas existentes, el lugar donde se encuentran y la finalidad de cada grupo.

## Resumen

El proyecto contiene actualmente:

- **89 pruebas en total**.
- **57 pruebas unitarias**, declaradas con `test()`.
- **32 pruebas de widgets**, declaradas con `testWidgets()`.
- **21 archivos de pruebas**.

Las pruebas unitarias comprueban logica de modelos y servicios sin renderizar la interfaz. Las pruebas de widgets montan pantallas o componentes Flutter para verificar textos, filtros, formularios, interacciones y estados visibles.

## Distribucion por area

| Area | Tipo principal | Cantidad | Finalidad |
|---|---|---:|---|
| `test/models/` | Unitarias | 10 | Validar modelos, conversion desde JSON, valores por defecto y `copyWith`. |
| `test/services/` | Unitarias | 47 | Validar reglas de negocio, payloads, transformaciones y acceso abstracto a datos. |
| `test/pages/` | Widgets | 27 | Validar pantallas completas, formularios, filtros, navegacion e interacciones. |
| `test/widgets/` | Widgets | 3 | Validar componentes visuales reutilizables. |
| `test/main_app_test.dart` y `test/widget_test.dart` | Widgets | 2 | Comprobar que la aplicacion y un arbol Flutter minimo se pueden renderizar. |

## Pruebas unitarias

### Modelos: `test/models/`

- **`cliente_afiliado_test.dart` - 3 pruebas**
  - Comprueba que `ClienteAfiliado` transforma correctamente los datos recibidos desde JSON.
  - Verifica valores por defecto cuando faltan campos.
  - Verifica la conversion numerica de las visitas validas y la activacion del descuento al alcanzar el limite.

- **`mesa_linea_pedido_test.dart` - 4 pruebas**
  - Comprueba la conversion de mesas desde JSON.
  - Verifica el estado por defecto y el estado explicito de una mesa.
  - Comprueba que una linea de pedido empieza con cantidad 1 y permite cambiar la cantidad.

- **`producto_test.dart` - 3 pruebas**
  - Comprueba la conversion completa de productos desde JSON.
  - Verifica valores por defecto de productos incompletos.
  - Comprueba que `copyWith` reemplaza solo los campos solicitados.

### Servicios: `test/services/`

- **`cliente_afiliado_service_test.dart` - 12 pruebas**
  - Comprueba el mapeo de clientes.
  - Valida la normalizacion y creacion de clientes.
  - Comprueba busquedas por numero de afiliado, DNI/CIF y codigo QR.
  - Valida el incremento y reinicio de visitas, descuentos y limites.
  - Comprueba el borrado y los casos de envio de correo sin datos suficientes.

- **`linea_pedido_service_test.dart` - 14 pruebas**
  - Comprueba calculos de totales y unidades.
  - Valida la insercion, incremento y eliminacion de lineas.
  - Comprueba el control de stock para botellas y copas.
  - Verifica errores cuando faltan productos, stock o datos de origen.
  - Comprueba la restauracion de stock al reducir o eliminar productos.
  - Valida la consulta y limpieza de lineas de un pedido.

- **`mesa_service_test.dart` - 2 pruebas**
  - Comprueba que las mesas ocupadas se determinan a partir de pedidos abiertos.
  - Verifica que el servicio delega correctamente la actualizacion del nombre de mesa.

- **`pedido_service_test.dart` - 10 pruebas**
  - Comprueba la obtencion o creacion de pedidos abiertos.
  - Valida el payload de cierre de pedidos, descuentos y afiliacion.
  - Comprueba la consulta de tickets cerrados por rango.
  - Verifica el mapeo de mesas, lineas, productos y fechas.
  - Comprueba la exclusion de pedidos con total cero.
  - Valida el informe personalizado por cliente, incluidos totales, ahorro y ticket medio.
  - Comprueba el tratamiento de campos nulos y fechas invalidas.

- **`pedido_value_objects_test.dart` - 4 pruebas**
  - Comprueba los objetos de datos usados por los informes de pedidos.
  - Valida el calculo de `totalLinea`.
  - Verifica listas de lineas vacias por defecto y conservacion de lineas proporcionadas.
  - Comprueba que los valores agregados de un informe de cliente se almacenan correctamente.

- **`producto_service_test.dart` - 1 prueba**
  - Comprueba que el servicio transforma las filas de productos en objetos de dominio.

- **`stock_service_test.dart` - 3 pruebas**
  - Comprueba el mapeo de productos con stock.
  - Verifica que la configuracion de stock se actualiza solo con payload valido.
  - Comprueba los payloads de creacion y actualizacion de productos.

- **`supabase_service_test.dart` - 1 prueba**
  - Comprueba que el servicio construye y delega correctamente el payload de insercion de un producto de demostracion.

## Pruebas de widgets

### Pantallas: `test/pages/`

- **`clientes_page_test.dart` - 5 pruebas**
  - Comprueba la carga y visualizacion de clientes.
  - Verifica la busqueda por texto.
  - Comprueba el borrado con dialogo de confirmacion.
  - Valida el alta desde el formulario inferior y la aparicion del dialogo QR.
  - Comprueba el snackbar cuando falla la carga.

- **`home_page_test.dart` - 2 pruebas**
  - Comprueba que la pantalla principal muestra los modulos y textos principales.
  - Verifica los layouts compacto y ancho.

- **`mesas_page_test.dart` - 2 pruebas**
  - Comprueba la estructura de la pantalla y la carga de mesas.
  - Verifica el nombre mostrado en mesas ocupadas y libres.

- **`producto_stock_form_page_test.dart` - 4 pruebas**
  - Comprueba valores iniciales y validacion de campos obligatorios.
  - Verifica que cambiar a categoria conserva oculta el campo de D.O. y actualiza el stock minimo.
  - Comprueba el payload al guardar un vino nuevo.
  - Verifica que el modo edicion conserva el stock minimo existente.

- **`scan_qr_page_test.dart` - 1 prueba**
  - Comprueba que la pantalla de escaneo muestra el titulo y el texto de ayuda.

- **`splash_screen_test.dart` - 1 prueba**
  - Comprueba que la pantalla inicial navega a `HomePage` despues del retraso configurado.

- **`stock_page_test.dart` - 12 pruebas**
  - Comprueba la visualizacion de productos compatibles con stock.
  - Valida busqueda, filtros por tipo, stock critico y denominacion de origen.
  - Comprueba aumentar y disminuir stock.
  - Valida la creacion y edicion de productos desde el formulario.
  - Comprueba la edicion del stock minimo y la validacion de valores invalidos.
  - Verifica rollback y mensajes visibles cuando fallan operaciones de stock o producto.
  - Comprueba el estado vacio cuando los filtros no encuentran resultados.
  - Valida el mensaje de error cuando falla la carga.

### Componentes y arranque

- **`test/widgets/watermark_background_test.dart` - 3 pruebas**
  - Comprueba que el componente renderiza su contenido.
  - Verifica la capa de degradado cuando recibe colores.
  - Comprueba que una ruta de imagen invalida no rompe el componente.

- **`test/main_app_test.dart` - 1 prueba**
  - Comprueba que `OsyraApp` configura un `MaterialApp` y su tema.

- **`test/widget_test.dart` - 1 prueba**
  - Prueba de humo para verificar que una aplicacion Flutter minima se renderiza correctamente.

## Que no cubren estas pruebas

Estas pruebas son principalmente unitarias y de widgets. No sustituyen completamente a las siguientes comprobaciones:

- Pruebas de integracion contra un proyecto Supabase real.
- Pruebas E2E del flujo completo de venta, afiliacion y descuento.
- Pruebas reales de impresion en Windows o Android.
- Validacion de envio de correos con Resend y secretos configurados.
- Pruebas de las Edge Functions desplegadas en Supabase.
- Pruebas completas de exportacion a Excel y PDF desde la interfaz de informes.

## Como ejecutarlas

Desde la raiz del proyecto:

```powershell
flutter test --reporter expanded
```

Para generar cobertura:

```powershell
flutter test --coverage
```

El resultado de cobertura se genera en `coverage/lcov.info`.
