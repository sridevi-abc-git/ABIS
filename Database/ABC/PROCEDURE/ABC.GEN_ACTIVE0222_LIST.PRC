CREATE OR REPLACE PROCEDURE ABC.gen_active0222_list
AS
-- **************************************************************************
-- File:        GEN_ACTIVE0222_LIST.PRC
-- Author:      CX
--
-- $Rev$
-- $Date$
-- Last Changed By:  $Author$
--
-- Description:
--
--
-- History:
-----------------------------------------------------------------------------
--    Date                  Comment
-- 08/20/2018 TJL         Initial Check-in
-- **************************************************************************

BEGIN
    abc.gen_active0222_rpt(NULL, NULL, NULL);
--commit; -- removed for production.

END gen_active0222_list;
/


GRANT EXECUTE ON ABC.GEN_ACTIVE0222_LIST TO POSSEEXTENSIONS;
