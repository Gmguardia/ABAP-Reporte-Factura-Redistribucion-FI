*&---------------------------------------------------------------------*
*& Include ZARFIR_APERTURAS_F01
*&---------------------------------------------------------------------*
*& Rutinas (FORM)
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*& Lectura VBRK / BKPF / BSEG
*&---------------------------------------------------------------------*
FORM obtener_datos.

  CLEAR: gt_bkpf, gt_bseg, gt_marc, gt_map, gt_docs, gt_out.

  " VBELN a 10 posiciones con ceros a la izquierda
  CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
    EXPORTING
      input  = p_vbeln
    IMPORTING
      output = gv_vbeln.

  " Pagador
  SELECT SINGLE kunrg
    FROM vbrk
    INTO @gv_kunrg
    WHERE vbeln = @gv_vbeln.
  IF sy-subrc <> 0.
    MESSAGE |La factura { gv_vbeln ALPHA = OUT } no existe| TYPE 'S' DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Sociedad del pagador
  CLEAR gv_vbund.
  SELECT SINGLE vbund
    FROM kna1
    INTO @gv_vbund
    WHERE kunnr = @gv_kunrg.

  " Documentos contables (AWKEY = VBELN de 10 posiciones)
  DATA(lv_awkey) = CONV bkpf-awkey( gv_vbeln ).

  SELECT bukrs, belnr, gjahr, hwaer
    FROM bkpf
    INTO TABLE @gt_bkpf
    WHERE awkey = @lv_awkey.
  IF sy-subrc <> 0.
    MESSAGE 'La factura no tiene documentos contables' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.
  SORT gt_bkpf BY bukrs belnr gjahr.

  " Posiciones contables
  SELECT bukrs, belnr, gjahr, buzei, hkont, dmbtr
    FROM bseg
    INTO TABLE @gt_bseg
    FOR ALL ENTRIES IN @gt_bkpf
    WHERE bukrs = @gt_bkpf-bukrs
      AND belnr = @gt_bkpf-belnr
      AND gjahr = @gt_bkpf-gjahr.
  SORT gt_bseg BY bukrs belnr gjahr buzei.

  " Marcas grabadas previamente (para mostrar el check inicial)
  SELECT *
    FROM zarfit_fact_marc
    INTO TABLE @gt_marc
    WHERE vbeln = @gv_vbeln.

ENDFORM.

*&---------------------------------------------------------------------*
*& Construcción del ALV árbol
*&---------------------------------------------------------------------*
FORM crear_arbol.

  DATA: lv_root TYPE salv_de_node_key,
        lv_doc  TYPE salv_de_node_key,
        lv_pos  TYPE salv_de_node_key,
        ls_out  TYPE ty_out,
        lv_text TYPE lvc_value.

  TRY.
      cl_salv_tree=>factory(
        EXPORTING r_container = go_dock
        IMPORTING r_salv_tree = go_tree
        CHANGING  t_table     = gt_out ).
    CATCH cx_salv_error INTO DATA(lx_salv).
      MESSAGE lx_salv TYPE 'E'.
  ENDTRY.

  " Funciones estándar + botones Grabar (ZSAVE) y Aperturas (ZAPER) sin status
  " propio. Sin documento contable no se ofrecen Grabar ni Aperturas.
  DATA(lo_functions) = go_tree->get_functions( ).
  lo_functions->set_all( abap_true ).
  IF gt_bkpf IS NOT INITIAL.
    TRY.
        lo_functions->add_function(
          name     = 'ZSAVE'
          icon     = CONV string( icon_system_save )
          text     = 'Grabar'
          tooltip  = 'Grabar marcas'
          position = if_salv_c_function_position=>right_of_salv_functions ).
        lo_functions->add_function(
          name     = 'ZAPER'
          icon     = CONV string( icon_detail )
          text     = 'Aperturas'
          tooltip  = 'Aperturas del documento contable de la factura'
          position = if_salv_c_function_position=>right_of_salv_functions ).
      CATCH cx_salv_existing cx_salv_wrong_call INTO DATA(lx_func).
        MESSAGE lx_func TYPE 'E'.
    ENDTRY.
  ENDIF.

  " Cabecera de la columna jerárquica
  DATA(lo_settings) = go_tree->get_tree_settings( ).
  lo_settings->set_hierarchy_header( 'Factura / Documento / Posición' ).
  lo_settings->set_hierarchy_size( 40 ).
  lo_settings->set_header( |Factura { gv_vbeln ALPHA = OUT }| ).

  " Columnas
  PERFORM configurar_columnas.

  DATA(lo_nodes) = go_tree->get_nodes( ).

  TRY.
      "------------------------------------------------------------ Nivel 1
      CLEAR ls_out.
      ls_out-vbeln = gv_vbeln.
      ls_out-kunrg = gv_kunrg.
      ls_out-vbund = gv_vbund.
      lv_text = |Factura { gv_vbeln ALPHA = OUT }|.

      DATA(lo_node) = lo_nodes->add_node(
        related_node = space
        relationship = cl_gui_column_tree=>relat_last_child
        data_row     = ls_out
        text         = lv_text
        folder       = abap_true ).
      lv_root = lo_node->get_key( ).

      LOOP AT gt_bkpf INTO DATA(ls_bkpf).
        "---------------------------------------------------------- Nivel 2
        CLEAR ls_out.
        ls_out-bukrs = ls_bkpf-bukrs.
        ls_out-belnr = ls_bkpf-belnr.
        ls_out-gjahr = ls_bkpf-gjahr.
        lv_text = |Doc. { ls_bkpf-belnr ALPHA = OUT }/{ ls_bkpf-gjahr }|.

        lo_node = lo_nodes->add_node(
          related_node = lv_root
          relationship = cl_gui_column_tree=>relat_last_child
          data_row     = ls_out
          text         = lv_text
          folder       = abap_true ).
        lv_doc = lo_node->get_key( ).
        INSERT VALUE #( node_key = lv_doc
                        bukrs    = ls_bkpf-bukrs
                        belnr    = ls_bkpf-belnr
                        gjahr    = ls_bkpf-gjahr
                        waers    = ls_bkpf-hwaer ) INTO TABLE gt_docs.

        LOOP AT gt_bseg INTO DATA(ls_bseg)
             WHERE bukrs = ls_bkpf-bukrs
               AND belnr = ls_bkpf-belnr
               AND gjahr = ls_bkpf-gjahr.
          "-------------------------------------------------------- Nivel 3
          CLEAR ls_out.
          ls_out-buzei = ls_bseg-buzei.
          ls_out-hkont = ls_bseg-hkont.
          ls_out-dmbtr = ls_bseg-dmbtr.
          ls_out-waers = ls_bkpf-hwaer.

          READ TABLE gt_marc INTO DATA(ls_marc)
               WITH TABLE KEY vbeln = gv_vbeln
                              bukrs = ls_bseg-bukrs
                              belnr = ls_bseg-belnr
                              gjahr = ls_bseg-gjahr
                              buzei = ls_bseg-buzei.
          IF sy-subrc = 0.
            ls_out-marca = ls_marc-marca.
          ENDIF.

          lv_text = |Pos. { ls_bseg-buzei }|.

          lo_node = lo_nodes->add_node(
            related_node = lv_doc
            relationship = cl_gui_column_tree=>relat_last_child
            data_row     = ls_out
            text         = lv_text ).
          lv_pos = lo_node->get_key( ).

          " Check editable en la columna MARCA
          DATA(lo_item) = lo_node->get_item( 'MARCA' ).
          lo_item->set_type( if_salv_c_item_type=>checkbox ).
          lo_item->set_editable( abap_true ).
          lo_item->set_checked( xsdbool( ls_out-marca = abap_true ) ).

          " Guardamos la relación nodo -> clave Z
          INSERT VALUE #( node_key   = lv_pos
                          data-mandt = sy-mandt
                          data-vbeln = gv_vbeln
                          data-bukrs = ls_bseg-bukrs
                          data-belnr = ls_bseg-belnr
                          data-gjahr = ls_bseg-gjahr
                          data-buzei = ls_bseg-buzei
                          data-marca = ls_out-marca ) INTO TABLE gt_map.
        ENDLOOP.
      ENDLOOP.

      lo_nodes->expand_all( ).

    CATCH cx_salv_msg INTO DATA(lx_msg).
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.

  " Eventos
  DATA(lo_events) = go_tree->get_event( ).
  SET HANDLER lcl_handler=>on_function FOR lo_events.
  SET HANDLER lcl_handler=>on_checkbox FOR lo_events.

ENDFORM.

*&---------------------------------------------------------------------*
*& Textos y formato de columnas
*&---------------------------------------------------------------------*
FORM configurar_columnas.

  DATA(lo_columns) = go_tree->get_columns( ).
  lo_columns->set_optimize( abap_true ).

  TRY.
      lo_columns->get_column( 'WAERS' )->set_visible( abap_false ).
      lo_columns->get_column( 'DMBTR' )->set_currency_column( 'WAERS' ).

      DATA(lo_col) = lo_columns->get_column( 'MARCA' ).
      lo_col->set_short_text( 'Marca' ).
      lo_col->set_medium_text( 'Marca' ).
      lo_col->set_long_text( 'Marca' ).
      lo_col->set_output_length( 6 ).

      lo_col = lo_columns->get_column( 'VBUND' ).
      lo_col->set_short_text( 'Soc.Pagad.' ).
      lo_col->set_medium_text( 'Sociedad del Pagador' ).
      lo_col->set_long_text( 'Sociedad del Pagador' ).

      lo_col = lo_columns->get_column( 'DMBTR' ).
      lo_col->set_medium_text( 'Importe ML' ).
      lo_col->set_long_text( 'Importe en moneda local' ).

    CATCH cx_salv_not_found cx_salv_data_error.
  ENDTRY.

ENDFORM.

*&---------------------------------------------------------------------*
*& Grabar en ZARFIT_FACT_MARC
*&---------------------------------------------------------------------*
FORM grabar USING    iv_silent TYPE abap_bool
            CHANGING cv_ok     TYPE abap_bool.

  DATA: lt_save  TYPE STANDARD TABLE OF zarfit_fact_marc,
        lv_subrc TYPE sy-subrc.

  cv_ok = abap_false.

  IF gt_map IS INITIAL.
    MESSAGE 'No hay posiciones para grabar' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " Solo se graban las posiciones marcadas; las desmarcadas se eliminan
  lt_save = VALUE #( FOR ls_map IN gt_map WHERE ( data-marca = abap_true )
                     ( ls_map-data ) ).

  DELETE FROM zarfit_fact_marc WHERE vbeln = @gv_vbeln.
  IF lt_save IS NOT INITIAL.
    INSERT zarfit_fact_marc FROM TABLE @lt_save.
    lv_subrc = sy-subrc.
  ENDIF.

  IF lv_subrc <> 0.
    ROLLBACK WORK.
    MESSAGE 'Error al grabar en ZARFIT_FACT_MARC' TYPE 'I' DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  COMMIT WORK.
  cv_ok = abap_true.

  " Grabación previa a abrir aperturas: sin mensajes
  CHECK iv_silent = abap_false.

  DATA lv_aviso TYPE string.
  PERFORM verificar_aperturas CHANGING lv_aviso.
  IF lv_aviso IS INITIAL.
    MESSAGE |Se grabaron { lines( lt_save ) } posiciones marcadas| TYPE 'S'.
  ELSE.
    MESSAGE |Se grabaron { lines( lt_save ) } posiciones marcadas. Atención, total marcado distinto de aperturas: { lv_aviso }|
            TYPE 'I' DISPLAY LIKE 'W'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Compara marcado vs aperturas grabadas (solo documentos con aperturas)
*&---------------------------------------------------------------------*
FORM verificar_aperturas CHANGING cv_aviso TYPE string.

  DATA: lv_sum TYPE dmbtr,
        lv_cnt TYPE i.

  CLEAR cv_aviso.
  LOOP AT gt_docs INTO DATA(ls_doc).
    CLEAR: lv_sum, lv_cnt.
    SELECT SUM( importe ), COUNT(*)
      FROM zarfit_fact_aper
      WHERE vbeln = @gv_vbeln
        AND bukrs = @ls_doc-bukrs
        AND belnr = @ls_doc-belnr
        AND gjahr = @ls_doc-gjahr
      INTO (@lv_sum, @lv_cnt).
    CHECK lv_cnt > 0.

    DATA(lv_marc) = lcl_aper=>sum_marcados( iv_bukrs = ls_doc-bukrs
                                            iv_belnr = ls_doc-belnr
                                            iv_gjahr = ls_doc-gjahr ).
    IF lv_sum <> lv_marc.
      IF cv_aviso IS NOT INITIAL.
        cv_aviso = cv_aviso && `; `.
      ENDIF.
      cv_aviso = cv_aviso &&
        |Doc. { ls_doc-belnr ALPHA = OUT }: marcado { lv_marc CURRENCY = ls_doc-waers NUMBER = USER }| &&
        | / aperturas { lv_sum CURRENCY = ls_doc-waers NUMBER = USER }|.
    ENDIF.
  ENDLOOP.

ENDFORM.

*&---------------------------------------------------------------------*
*& Botón Aperturas: la factura tiene a lo sumo un documento contable,
*& que se toma automáticamente
*&---------------------------------------------------------------------*
FORM abrir_aperturas.

  DATA ls_doc TYPE ty_doc.

  LOOP AT gt_docs INTO ls_doc.
    EXIT.
  ENDLOOP.
  IF sy-subrc <> 0.
    MESSAGE 'La factura no tiene documento contable' TYPE 'S' DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  " Antes de abrir las aperturas se graban las marcas de la primera pantalla
  DATA lv_ok TYPE abap_bool.
  PERFORM grabar USING abap_true CHANGING lv_ok.
  IF lv_ok = abap_false.
    RETURN.
  ENDIF.

  lcl_aper=>open( iv_bukrs = ls_doc-bukrs
                  iv_belnr = ls_doc-belnr
                  iv_gjahr = ls_doc-gjahr
                  iv_waers = ls_doc-waers ).

ENDFORM.
