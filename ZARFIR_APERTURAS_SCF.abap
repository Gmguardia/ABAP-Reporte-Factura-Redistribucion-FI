*&---------------------------------------------------------------------*
*& Include ZARFIR_APERTURAS_SCF
*&---------------------------------------------------------------------*
*& Pantallas de selección
*&---------------------------------------------------------------------*
*----------------------------------------------------------------------*
* Pantalla de selección
*----------------------------------------------------------------------*
PARAMETERS p_vbeln TYPE vbrk-vbeln OBLIGATORY.

* Pantalla contenedora del árbol (permite botones propios sin status)
SELECTION-SCREEN BEGIN OF SCREEN 100.
SELECTION-SCREEN COMMENT /1(1) gv_c100.
SELECTION-SCREEN END OF SCREEN 100.
