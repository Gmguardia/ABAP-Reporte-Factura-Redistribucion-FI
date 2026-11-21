# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Regla
Antes de cada modificacion guardar un backup de los archivos locales dentro de la carpeta backup, y dentro de la misma en una carpeta cuyo nombre esta formada por la fecha y hora

## Naturaleza del repositorio

No es un proyecto con build local. Los objetos ABAP viven en el sistema SAP **S4N_100_OSHPRO_ES** (mandante 100, paquete `$TMP`). Los ficheros `.abap` de esta carpeta son copias de trabajo del código fuente; la fuente de verdad es el sistema.

- Acceso al sistema: servidor MCP `oshpro` (ADT, `http://localhost:2236/mcp`, definido en [.mcp.json](.mcp.json)). Requiere que el servidor local esté arrancado.
- El workspace de VS Code ([SERVER.code-workspace](SERVER.code-workspace)) monta además el árbol de repositorio `abap:/repotree-v1/S4N_100_OSHPRO_ES`.

## Flujo de trabajo (herramientas MCP `oshpro`)

No hay comandos de build/lint/test por shell. Se usan las herramientas MCP:

- Localizar objeto: `abap_repository_search_object`
- Leer / editar fuente: `abap_object_read_file` / `abap_object_edit_file` (obtener la URI con `abap_object_get_file_uri` o `abap_object_list_file_uris`)
- Comprobar sintaxis: `abap_object_check`
- Activar: `abap_object_activate` (activar el programa principal y sus includes juntos tras cambios que crucen includes)
- ATC: `abap_atc_run_start` + `abap_atc_run_get_result`
- Tests unitarios: `abap_unit_run_tests` (actualmente no hay clases de test)

Si se edita un `.abap` local, sincronizar el cambio en el sistema (y viceversa); no asumir que la copia local está al día.

## Programa ZARFIR_APERTURAS

Report que parte de una factura SD y permite marcar posiciones contables y repartir su importe en "aperturas" (imputaciones a cuenta / CeCo / red-operación / PEP).

Estructura de includes (orden de inclusión relevante: `CLS` usa datos de `TOP`; las FORM de `F01` van al final y son llamadas desde `CLS`):

- [ZARFIR_APERTURAS.abap](ZARFIR_APERTURAS.abap) — programa principal y eventos.
- [ZARFIR_APERTURAS_TOP.abap](ZARFIR_APERTURAS_TOP.abap) — tipos y datos globales.
- [ZARFIR_APERTURAS_SCF.abap](ZARFIR_APERTURAS_SCF.abap) — `P_VBELN` y la pantalla de selección 100 (vacía, actúa de contenedor).
- [ZARFIR_APERTURAS_CLS.abap](ZARFIR_APERTURAS_CLS.abap) — `lcl_handler` (eventos del árbol) y `lcl_aper` (diálogo de aperturas).
- [ZARFIR_APERTURAS_F01.abap](ZARFIR_APERTURAS_F01.abap) — lectura de datos, construcción del árbol, grabación.

### Flujo

1. `obtener_datos`: VBRK (pagador) → BKPF por `AWKEY = VBELN` → BSEG → marcas previas de `ZARFIT_FACT_MARC`.
2. `CALL SELECTION-SCREEN 100`: en `AT SELECTION-SCREEN OUTPUT` se crea un `CL_GUI_DOCKING_CONTAINER` y dentro un `CL_SALV_TREE` de 3 niveles (factura → documento contable → posición con checkbox). Se usa una pantalla de selección como contenedor para tener botones propios sin GUI status; se excluyen ONLI/PRIN/SJOB/SPOS.
3. Funciones añadidas al árbol (`lcl_handler=>on_function`): grabar marcas (`FORM grabar`, `MODIFY ZARFIT_FACT_MARC`) y abrir aperturas (`FORM abrir_aperturas` → `lcl_aper=>open`).
4. `lcl_aper`: `CL_GUI_DIALOGBOX_CONTAINER` con cabecera `CL_DD_DOCUMENT` + `CL_GUI_ALV_GRID` editable sobre `ZARFIT_FACT_APER` para un documento (VBELN/BUKRS/BELNR/GJAHR).

### Estado y mapeos clave

- `gt_map` (hashed por `node_key`): nodo de posición → registro `ZARFIT_FACT_MARC`; el checkbox actualiza `data-marca` aquí. Es la fuente para grabar marcas y para `sum_marcados`.
- `gt_docs` (hashed por `node_key`): nodo de documento → clave BKPF + moneda.
- `gt_out` debe quedar vacía al llamar a `cl_salv_tree=>factory`; los nodos se añaden después.
- `gt_bseg` está ordenada por clave y se lee con `BINARY SEARCH`: mantener el `SORT` si se modifica la lectura.

### Reglas de negocio

- Guardar aperturas (`lcl_aper=>save`): descarta filas vacías → `validate` (convierte HKONT/KOSTL/NPLNR con ALPHA IN; valida contra SKB1, CSKS vigente vía KOKRS de TKA02, AUFK `autyp = '20'`, AFKO/AFVC, PRPS). Validaciones y F4 (cuenta, CeCo, red, operación, PEP, orden) usan la **sociedad del pagador** (`KNA1-VBUND` del `KUNRG`, en `gv_vbund` / `lcl_aper=>gv_bukrs_pag`; si está vacía, la del documento con aviso). La clave de `ZARFIT_FACT_APER` sigue siendo la BUKRS del documento contable → la suma de `IMPORTE` debe igualar la suma de DMBTR de las posiciones **marcadas** del documento → `assign_contador` → borrado completo + `INSERT` de las aperturas del documento.
- `CONTADOR`: autoincremental por documento; filas nuevas o copiadas (contador repetido) reciben máx + 1. También se reasigna en `on_changed_finished`.
- Al grabar marcas, `verificar_aperturas` avisa (no bloquea) si el total marcado difiere de las aperturas ya grabadas.
- Mensajes de error al usuario con `TYPE 'I' DISPLAY LIKE 'E'` para no abandonar los controles.

## Tablas Z

- `ZARFIT_FACT_MARC`: clave VBELN/BUKRS/BELNR/GJAHR/BUZEI + `MARCA`.
- `ZARFIT_FACT_APER`: clave VBELN/BUKRS/BELNR/GJAHR/CONTADOR; campos HKONT, KOSTL, NPLNR, VORNR, PS_PSP_PNR, IMPORTE.
