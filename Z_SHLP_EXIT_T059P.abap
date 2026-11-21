FUNCTION z_shlp_exit_t059p
  CHANGING
    VALUE(shlp) TYPE shlp_descr
    VALUE(callcontrol) LIKE ddshf4ctrl
  TABLES
    shlp_tab TYPE shlp_desct
    record_tab LIKE seahlpres.
*----------------------------------------------------------------------*
* Exit de ayuda de búsqueda: indicadores de retención (T059P)
* Parámetros esperados en la ayuda de búsqueda: LAND1, WITHT, TEXT40
* Texto desde T059U en idioma 'S'
*----------------------------------------------------------------------*
  TYPES: BEGIN OF ty_res,
           land1  TYPE t059p-land1,
           witht  TYPE t059p-witht,
           text40 TYPE t059u-text40,
         END OF ty_res.

  DATA: lt_res    TYPE STANDARD TABLE OF ty_res,
        lr_land1  TYPE RANGE OF t059p-land1,
        lr_witht  TYPE RANGE OF t059p-witht,
        lr_text40 TYPE RANGE OF t059u-text40,
        lv_max    TYPE i.

  CHECK callcontrol-step = 'SELECT'.

* Restricciones introducidas en el popup
  LOOP AT shlp-selopt ASSIGNING FIELD-SYMBOL(<ls_sel>).
    CASE <ls_sel>-shlpfield.
      WHEN 'LAND1'.
        APPEND VALUE #( sign = <ls_sel>-sign option = <ls_sel>-option
                        low  = <ls_sel>-low  high   = <ls_sel>-high ) TO lr_land1.
      WHEN 'WITHT'.
        APPEND VALUE #( sign = <ls_sel>-sign option = <ls_sel>-option
                        low  = <ls_sel>-low  high   = <ls_sel>-high ) TO lr_witht.
      WHEN 'TEXT40'.
        APPEND VALUE #( sign = <ls_sel>-sign option = <ls_sel>-option
                        low  = <ls_sel>-low  high   = <ls_sel>-high ) TO lr_text40.
    ENDCASE.
  ENDLOOP.

  lv_max = callcontrol-maxrecords.

  SELECT p~land1, p~witht, u~text40
    FROM t059p AS p
    LEFT OUTER JOIN t059u AS u
      ON  u~land1 = p~land1
      AND u~witht = p~witht
      AND u~spras = 'S'
    WHERE p~land1 IN @lr_land1
      AND p~witht IN @lr_witht
      AND u~text40 IN @lr_text40
    ORDER BY p~land1, p~witht
    INTO TABLE @lt_res
    UP TO @lv_max ROWS.

* Un registro 'NO' por país, siempre al principio (fuera de filtros)
  SELECT DISTINCT land1, 'NO' AS witht, 'NO' AS text40
    FROM t059p
    ORDER BY land1
    INTO TABLE @DATA(lt_no).

  INSERT LINES OF lt_no INTO lt_res INDEX 1.

  CALL FUNCTION 'F4UT_RESULTS_MAP'
    TABLES
      shlp_tab    = shlp_tab
      record_tab  = record_tab
      source_tab  = lt_res
    CHANGING
      shlp        = shlp
      callcontrol = callcontrol
    EXCEPTIONS
      OTHERS      = 1.
  IF sy-subrc = 0.
    callcontrol-step = 'DISP'.
  ELSE.
    callcontrol-step = 'EXIT'.
  ENDIF.

ENDFUNCTION.
