*&---------------------------------------------------------------------*
*& Include ZARFIR_APERTURAS_TOP
*&---------------------------------------------------------------------*
*& Definiciones globales: TYPES, DATA
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* Tipos
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_out,                 " Estructura de salida del árbol
         vbeln TYPE vbrk-vbeln,
         kunrg TYPE vbrk-kunrg,
         vbund TYPE kna1-vbund,         " Sociedad del pagador
         bukrs TYPE bkpf-bukrs,
         belnr TYPE bkpf-belnr,
         gjahr TYPE bkpf-gjahr,
         buzei TYPE bseg-buzei,
         hkont TYPE bseg-hkont,
         dmbtr TYPE bseg-dmbtr,
         waers TYPE bkpf-hwaer,
         marca TYPE c LENGTH 1,
       END OF ty_out,
       tt_out TYPE STANDARD TABLE OF ty_out WITH DEFAULT KEY.

TYPES: BEGIN OF ty_bkpf,
         bukrs TYPE bkpf-bukrs,
         belnr TYPE bkpf-belnr,
         gjahr TYPE bkpf-gjahr,
         hwaer TYPE bkpf-hwaer,
       END OF ty_bkpf,
       tt_bkpf TYPE STANDARD TABLE OF ty_bkpf WITH DEFAULT KEY.

TYPES: BEGIN OF ty_bseg,
         bukrs TYPE bseg-bukrs,
         belnr TYPE bseg-belnr,
         gjahr TYPE bseg-gjahr,
         buzei TYPE bseg-buzei,
         hkont TYPE bseg-hkont,
         dmbtr TYPE bseg-dmbtr,
       END OF ty_bseg,
       tt_bseg TYPE STANDARD TABLE OF ty_bseg WITH DEFAULT KEY.

* Relación nodo del árbol (nivel 3) -> registro a grabar
TYPES: BEGIN OF ty_map,
         node_key TYPE salv_de_node_key,
         data     TYPE zarfit_fact_marc,
       END OF ty_map,
       tt_map TYPE HASHED TABLE OF ty_map WITH UNIQUE KEY node_key.

*----------------------------------------------------------------------*
* Datos globales
*----------------------------------------------------------------------*
DATA: gv_vbeln TYPE vbrk-vbeln,
      gv_kunrg TYPE vbrk-kunrg,
      gv_vbund TYPE kna1-vbund,         " Sociedad del pagador (KNA1-VBUND)
      gt_bkpf  TYPE tt_bkpf,
      gt_bseg  TYPE tt_bseg,
      gt_marc  TYPE SORTED TABLE OF zarfit_fact_marc
                    WITH UNIQUE KEY vbeln bukrs belnr gjahr buzei,
      gt_map   TYPE tt_map,
      gt_out   TYPE tt_out,             " Debe estar vacía para el factory
      go_tree  TYPE REF TO cl_salv_tree,
      go_dock  TYPE REF TO cl_gui_docking_container.

* Documentos contables del árbol (nodo nivel 2 -> clave)
TYPES: BEGIN OF ty_doc,
         node_key TYPE salv_de_node_key,
         bukrs    TYPE bkpf-bukrs,
         belnr    TYPE bkpf-belnr,
         gjahr    TYPE bkpf-gjahr,
         waers    TYPE bkpf-hwaer,
       END OF ty_doc.
DATA gt_docs TYPE HASHED TABLE OF ty_doc WITH UNIQUE KEY node_key.

* Funciones excluidas del status de la pantalla 100
DATA gt_excl TYPE STANDARD TABLE OF rsexfcode.
