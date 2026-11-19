*&---------------------------------------------------------------------*
*& Include ZARFIR_APERTURAS_CLS
*&---------------------------------------------------------------------*
*& Clases locales (definición e implementación)
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* Manejador de eventos
*----------------------------------------------------------------------*
CLASS lcl_handler DEFINITION.
  PUBLIC SECTION.
    CLASS-METHODS:
      on_function FOR EVENT added_function OF cl_salv_events_tree
        IMPORTING e_salv_function,
      on_checkbox FOR EVENT checkbox_change OF cl_salv_events_tree
        IMPORTING columnname node_key checked.
ENDCLASS.

*----------------------------------------------------------------------*
* Pantalla de aperturas (ZARFIT_FACT_APER) para un documento contable
*----------------------------------------------------------------------*
CLASS lcl_aper DEFINITION.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_aper.
             INCLUDE TYPE zarfit_fact_aper.
    TYPES:   waers TYPE bkpf-waers,
           END OF ty_aper,
           tt_aper TYPE STANDARD TABLE OF ty_aper WITH DEFAULT KEY.

    CLASS-METHODS open
      IMPORTING iv_bukrs TYPE bkpf-bukrs
                iv_belnr TYPE bkpf-belnr
                iv_gjahr TYPE bkpf-gjahr
                iv_waers TYPE bkpf-hwaer.

    " Suma DMBTR de las posiciones marcadas en el árbol para un documento
    CLASS-METHODS sum_marcados
      IMPORTING iv_bukrs      TYPE bkpf-bukrs
                iv_belnr      TYPE bkpf-belnr
                iv_gjahr      TYPE bkpf-gjahr
      RETURNING VALUE(rv_sum) TYPE dmbtr.

  PRIVATE SECTION.
    CLASS-DATA: go_dialog TYPE REF TO cl_gui_dialogbox_container,
                go_doc    TYPE REF TO cl_dd_document,
                go_grid   TYPE REF TO cl_gui_alv_grid,
                gs_key    TYPE ty_aper,
                gt_aper   TYPE tt_aper.

    CLASS-METHODS:
      close_window,
      read_data,
      build_header IMPORTING io_parent TYPE REF TO cl_gui_container,
      build_grid   IMPORTING io_parent TYPE REF TO cl_gui_container,
      save,
      validate     RETURNING VALUE(rv_ok) TYPE abap_bool,
      assign_contador RETURNING VALUE(rv_changed) TYPE abap_bool,
      f4_popup     IMPORTING iv_retfield     TYPE dfies-fieldname
                   CHANGING  ct_values       TYPE STANDARD TABLE
                   RETURNING VALUE(rv_value) TYPE shvalue_d,
      on_changed_finished FOR EVENT data_changed_finished OF cl_gui_alv_grid
        IMPORTING e_modified,
      on_close     FOR EVENT close OF cl_gui_dialogbox_container,
      on_toolbar   FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object,
      on_command   FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      on_f4        FOR EVENT onf4 OF cl_gui_alv_grid
        IMPORTING e_fieldname es_row_no er_event_data.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_handler IMPLEMENTATION.
*----------------------------------------------------------------------*
  METHOD on_function.
    DATA lv_ok TYPE abap_bool.
    CASE e_salv_function.
      WHEN 'ZSAVE'.
        PERFORM grabar USING abap_false CHANGING lv_ok.
      WHEN 'ZAPER'.
        PERFORM abrir_aperturas.
    ENDCASE.
  ENDMETHOD.

  METHOD on_checkbox.
    CHECK columnname = 'MARCA'.
    ASSIGN gt_map[ node_key = node_key ] TO FIELD-SYMBOL(<ls_map>).
    IF sy-subrc = 0.
      <ls_map>-data-marca = COND #( WHEN checked = abap_true THEN abap_true
                                    ELSE space ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
CLASS lcl_aper IMPLEMENTATION.
*----------------------------------------------------------------------*
  METHOD open.

    close_window( ).

    gs_key = VALUE #( mandt = sy-mandt
                      vbeln = gv_vbeln
                      bukrs = iv_bukrs
                      belnr = iv_belnr
                      gjahr = iv_gjahr
                      waers = iv_waers ).
    read_data( ).

    DATA lv_caption TYPE c LENGTH 100.
    lv_caption = |Aperturas - Doc. { iv_belnr ALPHA = OUT }/{ iv_gjahr }|.

    go_dialog = NEW #(
      width   = 1020
      height  = 294
      top     = 60
      left    = 60
      caption = lv_caption ).
    SET HANDLER on_close FOR go_dialog.

    DATA(lo_split) = NEW cl_gui_splitter_container( parent  = go_dialog
                                                    rows    = 2
                                                    columns = 1 ).
    " Cabecera de alto fijo en píxeles
    lo_split->set_row_mode( mode = cl_gui_splitter_container=>mode_absolute ).
    lo_split->set_row_height( id = 1 height = 100 ).

    build_header( lo_split->get_container( row = 1 column = 1 ) ).
    build_grid( lo_split->get_container( row = 2 column = 1 ) ).

  ENDMETHOD.

  METHOD close_window.
    IF go_grid IS BOUND.
      go_grid->free( ).
      CLEAR go_grid.
    ENDIF.
    CLEAR go_doc.
    IF go_dialog IS BOUND.
      go_dialog->free( ).
      CLEAR go_dialog.
    ENDIF.
  ENDMETHOD.

  METHOD read_data.
    CLEAR gt_aper.
    SELECT *
      FROM zarfit_fact_aper
      WHERE vbeln = @gs_key-vbeln
        AND bukrs = @gs_key-bukrs
        AND belnr = @gs_key-belnr
        AND gjahr = @gs_key-gjahr
      ORDER BY contador
      INTO CORRESPONDING FIELDS OF TABLE @gt_aper.
    LOOP AT gt_aper ASSIGNING FIELD-SYMBOL(<ls_aper>).
      <ls_aper>-waers = gs_key-waers.
    ENDLOOP.
  ENDMETHOD.

  METHOD build_header.

    SELECT SINGLE name1 FROM kna1
      WHERE kunnr = @gv_kunrg
      INTO @DATA(lv_name1).

    SELECT SINGLE blart, bldat, budat, xblnr FROM bkpf
      WHERE bukrs = @gs_key-bukrs
        AND belnr = @gs_key-belnr
        AND gjahr = @gs_key-gjahr
      INTO @DATA(ls_bkpf).

    go_doc = NEW #( ).
    go_doc->add_text(
      text      = CONV #( |Factura: { gv_vbeln ALPHA = OUT }     Pagador: { gv_kunrg ALPHA = OUT } { lv_name1 }| )
      sap_emphasis = cl_dd_area=>strong ).
    go_doc->new_line( ).
    go_doc->add_text(
      text = CONV #( |Documento: { gs_key-bukrs } / { gs_key-belnr ALPHA = OUT } / { gs_key-gjahr }| &&
                     |     Clase: { ls_bkpf-blart }     Fecha doc.: { ls_bkpf-bldat DATE = USER }| &&
                     |     Contab.: { ls_bkpf-budat DATE = USER }     Ref.: { ls_bkpf-xblnr }| &&
                     |     Moneda: { gs_key-waers }| ) ).

    " Importe total de las posiciones marcadas en la primera pantalla
    DATA(lv_marc) = sum_marcados( iv_bukrs = gs_key-bukrs
                                  iv_belnr = gs_key-belnr
                                  iv_gjahr = gs_key-gjahr ).
    go_doc->new_line( ).
    go_doc->add_text(
      text         = CONV #( |Importe marcado: { lv_marc CURRENCY = gs_key-waers NUMBER = USER } { gs_key-waers }| )
      sap_emphasis = cl_dd_area=>strong ).
    go_doc->display_document( parent = io_parent ).

  ENDMETHOD.

  METHOD build_grid.

    DATA lt_fcat TYPE lvc_t_fcat.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name = 'ZARFIT_FACT_APER'
      CHANGING
        ct_fieldcat      = lt_fcat
      EXCEPTIONS
        OTHERS           = 1.

    " Campos editables con ayuda de búsqueda por referencia DDIC
    LOOP AT lt_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
      CASE <ls_fcat>-fieldname.
        WHEN 'MANDT' OR 'VBELN' OR 'BUKRS' OR 'BELNR' OR 'GJAHR'.
          <ls_fcat>-tech = abap_true.
        WHEN 'CONTADOR'.
          <ls_fcat>-coltext   = 'Nº'.
          <ls_fcat>-outputlen = 5.
        WHEN 'HKONT'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-ref_table  = 'BSEG'.
          <ls_fcat>-ref_field  = 'HKONT'.
          <ls_fcat>-checktable = '!'.   " Sin check DDIC: se valida al grabar
          <ls_fcat>-f4availabl = abap_true.   " F4 propio filtrado por sociedad
        WHEN 'KOSTL'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-ref_table  = 'CSKS'.
          <ls_fcat>-ref_field  = 'KOSTL'.
          <ls_fcat>-checktable = '!'.
          <ls_fcat>-f4availabl = abap_true.   " F4 propio filtrado por sociedad
        WHEN 'NPLNR'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-ref_table  = 'BSEG'.
          <ls_fcat>-ref_field  = 'NPLNR'.
          <ls_fcat>-checktable = '!'.
          <ls_fcat>-f4availabl = abap_true.   " F4 propio (redes de la sociedad)
        WHEN 'ORDEN'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-ref_table  = 'AUFK'.
          <ls_fcat>-ref_field  = 'AUFNR'.
          <ls_fcat>-checktable = '!'.
          <ls_fcat>-coltext    = 'Orden'.
          <ls_fcat>-f4availabl = abap_true.   " F4 propio (órdenes de la sociedad)
        WHEN 'VORNR'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-f4availabl = abap_true.   " F4 propio (operaciones de la red)
        WHEN 'PS_PSP_PNR'.
          <ls_fcat>-edit      = abap_true.
          <ls_fcat>-ref_table  = 'PRPS'.
          <ls_fcat>-ref_field  = 'PSPNR'.
          <ls_fcat>-checktable = '!'.
          <ls_fcat>-f4availabl = abap_true.   " F4 propio (PEP de la sociedad)
        WHEN 'IMPORTE'.
          <ls_fcat>-edit       = abap_true.
          <ls_fcat>-cfieldname = 'WAERS'.
          <ls_fcat>-do_sum     = abap_true.
      ENDCASE.
    ENDLOOP.

    " Anchos de columna
    LOOP AT lt_fcat ASSIGNING <ls_fcat>.
      <ls_fcat>-outputlen = SWITCH #( <ls_fcat>-fieldname
                                      WHEN 'CONTADOR'   THEN 6
                                      WHEN 'HKONT'      THEN 16
                                      WHEN 'KOSTL'      THEN 16
                                      WHEN 'NPLNR'      THEN 16
                                      WHEN 'ORDEN'      THEN 16
                                      WHEN 'VORNR'      THEN 10
                                      WHEN 'PS_PSP_PNR' THEN 28
                                      WHEN 'IMPORTE'    THEN 22
                                      ELSE <ls_fcat>-outputlen ).
    ENDLOOP.

    APPEND VALUE #( fieldname = 'WAERS'
                    ref_table = 'BKPF'
                    ref_field = 'WAERS'
                    no_out    = abap_true ) TO lt_fcat.

    go_grid = NEW #( i_parent = io_parent ).
    SET HANDLER on_toolbar on_command on_f4 on_changed_finished FOR go_grid.

    DATA(lt_f4) = VALUE lvc_t_f4(
      register = abap_true getbefore = abap_true chngeafter = abap_true
      ( fieldname = 'HKONT' )
      ( fieldname = 'KOSTL' )
      ( fieldname = 'NPLNR' )
      ( fieldname = 'ORDEN' )
      ( fieldname = 'PS_PSP_PNR' )
      ( fieldname = 'VORNR' ) ).
    go_grid->register_f4_for_fields( lt_f4 ).
    go_grid->register_edit_event( cl_gui_alv_grid=>mc_evt_modified ).

    DATA(ls_layo) = VALUE lvc_s_layo( sel_mode   = 'A'
                                      grid_title = 'Aperturas' ).

    go_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = ls_layo
      CHANGING
        it_outtab       = gt_aper
        it_fieldcatalog = lt_fcat ).
    go_grid->set_ready_for_input( 1 ).

  ENDMETHOD.

  METHOD on_toolbar.
    APPEND VALUE #( butn_type = 3 ) TO e_object->mt_toolbar.
    APPEND VALUE #( function  = 'ZSAVE_AP'
                    icon      = icon_system_save
                    text      = 'Grabar'
                    quickinfo = 'Grabar aperturas' ) TO e_object->mt_toolbar.
    APPEND VALUE #( function  = 'ZEXIT_AP'
                    icon      = icon_close
                    text      = 'Salir'
                    quickinfo = 'Cerrar la pantalla de aperturas' ) TO e_object->mt_toolbar.
  ENDMETHOD.

  METHOD on_command.
    CASE e_ucomm.
      WHEN 'ZSAVE_AP'.
        save( ).
      WHEN 'ZEXIT_AP'.
        close_window( ).
    ENDCASE.
  ENDMETHOD.

  METHOD validate.

    DATA lv_x TYPE abap_bool.

    rv_ok = abap_true.

    " Formato interno (ceros a la izquierda) antes de validar contra BD
    LOOP AT gt_aper ASSIGNING FIELD-SYMBOL(<ls_conv>).
      IF <ls_conv>-hkont IS NOT INITIAL.
        <ls_conv>-hkont = |{ <ls_conv>-hkont ALPHA = IN }|.
      ENDIF.
      IF <ls_conv>-kostl IS NOT INITIAL.
        <ls_conv>-kostl = |{ <ls_conv>-kostl ALPHA = IN }|.
      ENDIF.
      IF <ls_conv>-nplnr IS NOT INITIAL.
        <ls_conv>-nplnr = |{ <ls_conv>-nplnr ALPHA = IN }|.
      ENDIF.
      IF <ls_conv>-orden IS NOT INITIAL.
        <ls_conv>-orden = |{ <ls_conv>-orden ALPHA = IN }|.
      ENDIF.
    ENDLOOP.

    SELECT SINGLE kokrs FROM tka02
      WHERE bukrs = @gs_key-bukrs
      INTO @DATA(lv_kokrs).

    LOOP AT gt_aper INTO DATA(ls_aper).
      DATA(lv_row) = sy-tabix.

      IF ls_aper-hkont IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM skb1
          WHERE bukrs = @gs_key-bukrs
            AND saknr = @ls_aper-hkont
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: la cuenta { ls_aper-hkont ALPHA = OUT } no existe en la sociedad { gs_key-bukrs }|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      IF ls_aper-kostl IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM csks
          WHERE kokrs  = @lv_kokrs
            AND kostl  = @ls_aper-kostl
            AND datbi >= @sy-datum
            AND datab <= @sy-datum
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: el centro de coste { ls_aper-kostl ALPHA = OUT } no existe o no es válido|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      IF ls_aper-nplnr IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM aufk
          WHERE aufnr = @ls_aper-nplnr
            AND autyp = '20'
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: la red { ls_aper-nplnr ALPHA = OUT } no existe|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      IF ls_aper-orden IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM aufk
          WHERE aufnr  = @ls_aper-orden
            AND bukrs  = @gs_key-bukrs
            AND autyp <> '20'
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: la orden { ls_aper-orden ALPHA = OUT } no existe en la sociedad { gs_key-bukrs }|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      IF ls_aper-vornr IS NOT INITIAL.
        IF ls_aper-nplnr IS INITIAL.
          MESSAGE |Fila { lv_row }: indique la red para la operación { ls_aper-vornr }|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
        SELECT SINGLE @abap_true
          FROM afko INNER JOIN afvc ON afvc~aufpl = afko~aufpl
          WHERE afko~aufnr = @ls_aper-nplnr
            AND afvc~vornr = @ls_aper-vornr
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: la operación { ls_aper-vornr } no existe en la red { ls_aper-nplnr ALPHA = OUT }|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.

      IF ls_aper-ps_psp_pnr IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM prps
          WHERE pspnr = @ls_aper-ps_psp_pnr
          INTO @lv_x.
        IF sy-subrc <> 0.
          MESSAGE |Fila { lv_row }: el elemento PEP no existe|
                  TYPE 'I' DISPLAY LIKE 'E'.
          rv_ok = abap_false.
          RETURN.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD save.

    DATA: lt_db    TYPE STANDARD TABLE OF zarfit_fact_aper,
          lv_subrc TYPE sy-subrc.

    go_grid->check_changed_data( ).

    " Filas totalmente vacías no se graban
    DELETE gt_aper WHERE hkont      IS INITIAL
                     AND kostl      IS INITIAL
                     AND nplnr      IS INITIAL
                     AND orden      IS INITIAL
                     AND vornr      IS INITIAL
                     AND ps_psp_pnr IS INITIAL
                     AND importe    IS INITIAL.

    IF validate( ) = abap_false.
      go_grid->refresh_table_display( ).
      RETURN.
    ENDIF.

    " Total aperturas debe coincidir con el total de posiciones marcadas
    DATA lv_aper TYPE dmbtr.
    DATA(lv_marc) = sum_marcados( iv_bukrs = gs_key-bukrs
                                  iv_belnr = gs_key-belnr
                                  iv_gjahr = gs_key-gjahr ).
    LOOP AT gt_aper INTO DATA(ls_sum).
      lv_aper = lv_aper + ls_sum-importe.
    ENDLOOP.
    IF gt_aper IS NOT INITIAL AND lv_aper <> lv_marc.
      MESSAGE |Total aperturas { lv_aper CURRENCY = gs_key-waers NUMBER = USER } distinto del total marcado | &&
              |{ lv_marc CURRENCY = gs_key-waers NUMBER = USER } { gs_key-waers }. No se grabó.|
              TYPE 'I' DISPLAY LIKE 'E'.
      go_grid->refresh_table_display( ).
      RETURN.
    ENDIF.

    " Clave completa y contador para filas nuevas / copiadas
    assign_contador( ).

    lt_db = CORRESPONDING #( gt_aper ).

    " Reemplazo completo de las aperturas del documento (alta/modif./baja)
    DELETE FROM zarfit_fact_aper
      WHERE vbeln = @gs_key-vbeln
        AND bukrs = @gs_key-bukrs
        AND belnr = @gs_key-belnr
        AND gjahr = @gs_key-gjahr.
    IF lt_db IS NOT INITIAL.
      INSERT zarfit_fact_aper FROM TABLE @lt_db.
      lv_subrc = sy-subrc.
    ENDIF.

    IF lv_subrc = 0.
      COMMIT WORK.
      MESSAGE |Aperturas grabadas: { lines( lt_db ) }| TYPE 'S'.
    ELSE.
      ROLLBACK WORK.
      MESSAGE 'Error al grabar en ZARFIT_FACT_APER' TYPE 'I' DISPLAY LIKE 'E'.
    ENDIF.

    read_data( ).
    go_grid->refresh_table_display( ).

  ENDMETHOD.

  METHOD on_f4.

    FIELD-SYMBOLS <lt_modi> TYPE lvc_t_modi.
    DATA lv_value TYPE shvalue_d.

    er_event_data->m_event_handled = abap_true.

    CASE e_fieldname.
      WHEN 'HKONT'.
        " Cuentas de mayor creadas en la sociedad del documento
        SELECT SINGLE ktopl FROM t001
          WHERE bukrs = @gs_key-bukrs
          INTO @DATA(lv_ktopl).
        SELECT b~saknr, t~txt50
          FROM skb1 AS b
          LEFT OUTER JOIN skat AS t ON  t~saknr = b~saknr
                                    AND t~ktopl = @lv_ktopl
                                    AND t~spras = @sy-langu
          WHERE b~bukrs = @gs_key-bukrs
          ORDER BY b~saknr
          INTO TABLE @DATA(lt_hkont).
        lv_value = f4_popup( EXPORTING iv_retfield = 'SAKNR'
                             CHANGING  ct_values   = lt_hkont ).

      WHEN 'KOSTL'.
        " Centros de coste vigentes de la sociedad del documento
        SELECT SINGLE kokrs FROM tka02
          WHERE bukrs = @gs_key-bukrs
          INTO @DATA(lv_kokrs).
        SELECT c~kostl, t~ktext
          FROM csks AS c
          LEFT OUTER JOIN cskt AS t ON  t~kokrs = c~kokrs
                                    AND t~kostl = c~kostl
                                    AND t~datbi = c~datbi
                                    AND t~spras = @sy-langu
          WHERE c~kokrs  = @lv_kokrs
            AND c~bukrs  = @gs_key-bukrs
            AND c~datbi >= @sy-datum
            AND c~datab <= @sy-datum
          ORDER BY c~kostl
          INTO TABLE @DATA(lt_kostl).
        lv_value = f4_popup( EXPORTING iv_retfield = 'KOSTL'
                             CHANGING  ct_values   = lt_kostl ).

      WHEN 'NPLNR'.
        " Redes (grafos) de la sociedad del documento
        SELECT aufnr, ktext
          FROM aufk
          WHERE autyp = '20'
            AND bukrs = @gs_key-bukrs
            AND loekz = @space
          ORDER BY aufnr
          INTO TABLE @DATA(lt_nplnr).
        lv_value = f4_popup( EXPORTING iv_retfield = 'AUFNR'
                             CHANGING  ct_values   = lt_nplnr ).

      WHEN 'ORDEN'.
        " Órdenes (excepto redes) de la sociedad del documento
        SELECT aufnr, auart, ktext
          FROM aufk
          WHERE autyp <> '20'
            AND bukrs  = @gs_key-bukrs
            AND loekz  = @space
          ORDER BY aufnr
          INTO TABLE @DATA(lt_orden).
        lv_value = f4_popup( EXPORTING iv_retfield = 'AUFNR'
                             CHANGING  ct_values   = lt_orden ).

      WHEN 'PS_PSP_PNR'.
        " Elementos PEP de la sociedad del documento
        SELECT posid, post1
          FROM prps
          WHERE pbukr = @gs_key-bukrs
            AND loevm = @space
          ORDER BY posid
          INTO TABLE @DATA(lt_pep).
        lv_value = f4_popup( EXPORTING iv_retfield = 'POSID'
                             CHANGING  ct_values   = lt_pep ).

      WHEN 'VORNR'.
        " Operaciones de la red de la fila
        READ TABLE gt_aper INTO DATA(ls_row) INDEX es_row_no-row_id.
        IF ls_row-nplnr IS INITIAL.
          MESSAGE 'Indique primero la red' TYPE 'S' DISPLAY LIKE 'W'.
          RETURN.
        ENDIF.
        SELECT afvc~vornr, afvc~ltxa1
          FROM afko INNER JOIN afvc ON afvc~aufpl = afko~aufpl
          WHERE afko~aufnr = @ls_row-nplnr
          ORDER BY afvc~vornr
          INTO TABLE @DATA(lt_vornr).
        lv_value = f4_popup( EXPORTING iv_retfield = 'VORNR'
                             CHANGING  ct_values   = lt_vornr ).
    ENDCASE.

    IF lv_value IS NOT INITIAL.
      ASSIGN er_event_data->m_data->* TO <lt_modi>.
      APPEND VALUE #( row_id    = es_row_no-row_id
                      fieldname = e_fieldname
                      value     = lv_value ) TO <lt_modi>.
    ENDIF.

  ENDMETHOD.

  METHOD f4_popup.

    DATA lt_ret TYPE STANDARD TABLE OF ddshretval.

    CALL FUNCTION 'F4IF_INT_TABLE_VALUE_REQUEST'
      EXPORTING
        retfield   = iv_retfield
        value_org  = 'S'
      TABLES
        value_tab  = ct_values
        return_tab = lt_ret
      EXCEPTIONS
        OTHERS     = 1.

    IF sy-subrc = 0 AND lt_ret IS NOT INITIAL.
      rv_value = lt_ret[ 1 ]-fieldval.
    ENDIF.

  ENDMETHOD.

  METHOD on_close.
    close_window( ).
  ENDMETHOD.

  METHOD sum_marcados.
    LOOP AT gt_map INTO DATA(ls_map) WHERE data-bukrs = iv_bukrs
                                       AND data-belnr = iv_belnr
                                       AND data-gjahr = iv_gjahr
                                       AND data-marca = abap_true.
      READ TABLE gt_bseg INTO DATA(ls_bseg)
           WITH KEY bukrs = ls_map-data-bukrs
                    belnr = ls_map-data-belnr
                    gjahr = ls_map-data-gjahr
                    buzei = ls_map-data-buzei
           BINARY SEARCH.
      IF sy-subrc = 0.
        rv_sum = rv_sum + ls_bseg-dmbtr.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD assign_contador.
    " Contador autoincremental por clave VBELN/BUKRS/BELNR/GJAHR:
    " las filas sin contador (nuevas) o con contador repetido (copiadas)
    " reciben el máximo del documento + 1.
    DATA: lv_max  TYPE int4,
          lt_used TYPE SORTED TABLE OF int4 WITH UNIQUE KEY table_line.

    LOOP AT gt_aper INTO DATA(ls_max) WHERE contador > lv_max.
      lv_max = ls_max-contador.
    ENDLOOP.

    LOOP AT gt_aper ASSIGNING FIELD-SYMBOL(<ls_aper>).
      <ls_aper>-mandt = sy-mandt.
      <ls_aper>-vbeln = gs_key-vbeln.
      <ls_aper>-bukrs = gs_key-bukrs.
      <ls_aper>-belnr = gs_key-belnr.
      <ls_aper>-gjahr = gs_key-gjahr.
      <ls_aper>-waers = gs_key-waers.
      IF <ls_aper>-contador IS INITIAL
         OR line_exists( lt_used[ table_line = <ls_aper>-contador ] ).
        lv_max = lv_max + 1.
        <ls_aper>-contador = lv_max.
        rv_changed = abap_true.
      ENDIF.
      INSERT <ls_aper>-contador INTO TABLE lt_used.
    ENDLOOP.
  ENDMETHOD.

  METHOD on_changed_finished.
    CHECK e_modified = abap_true.
    IF assign_contador( ) = abap_true.
      go_grid->refresh_table_display(
        is_stable      = VALUE #( row = abap_true col = abap_true )
        i_soft_refresh = abap_true ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
