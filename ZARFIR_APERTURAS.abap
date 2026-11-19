*&---------------------------------------------------------------------*
*& Report ZARFIR_APERTURAS
*&---------------------------------------------------------------------*
*& Factura (VBRK) -> Documentos contables (BKPF) -> Posiciones (BSEG)
*& ALV jerárquico (CL_SALV_TREE) con check por posición y grabación
*& en la tabla ZARFIT_FACT_MARC.
*& Paquete: $TMP
*&---------------------------------------------------------------------*
REPORT zarfir_aperturas.

INCLUDE zarfir_aperturas_top.   " Datos globales
INCLUDE zarfir_aperturas_scf.   " Pantallas de selección
INCLUDE zarfir_aperturas_cls.   " Clases locales

*----------------------------------------------------------------------*
AT SELECTION-SCREEN OUTPUT.
*----------------------------------------------------------------------*
  IF sy-dynnr = '0100'.
    " Sin Ejecutar / Imprimir / Fondo / Guardar variante en la pantalla del árbol
    gt_excl = VALUE #( ( fcode = 'ONLI' ) ( fcode = 'PRIN' ) ( fcode = 'SJOB' )
                       ( fcode = 'SPOS' ) ).
    CALL FUNCTION 'RS_SET_SELSCREEN_STATUS'
      EXPORTING
        p_status  = sy-pfkey
      TABLES
        p_exclude = gt_excl.

    IF go_dock IS NOT BOUND.
      go_dock = NEW #( repid     = sy-repid
                       dynnr     = '0100'
                       side      = cl_gui_docking_container=>dock_at_bottom
                       extension = 2000 ).
      PERFORM crear_arbol.
      go_tree->display( ).
    ENDIF.
  ENDIF.

*----------------------------------------------------------------------*
START-OF-SELECTION.
*----------------------------------------------------------------------*
  PERFORM obtener_datos.
  CALL SELECTION-SCREEN 100.

  " Al salir de la pantalla del árbol se liberan los controles
  IF go_dock IS BOUND.
    go_dock->free( ).
  ENDIF.
  CLEAR: go_dock, go_tree.

*----------------------------------------------------------------------*
* Rutinas
*----------------------------------------------------------------------*
INCLUDE zarfir_aperturas_f01.
