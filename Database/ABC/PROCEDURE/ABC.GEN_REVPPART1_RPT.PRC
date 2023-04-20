CREATE OR REPLACE PROCEDURE ABC.gen_revppart1_rpt(
    a_lbjobid       api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        GEN_REVPPART1_RPT.PRC
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
    /* parameter a_lbjobid is license batch jobid  */
    /* generate revocation pending - part 1 report */
    /* test license batch jobid (228003, 228016)   */

BEGIN
    abc.gen_revpfinal_rpt(a_lbjobid);
END gen_revppart1_rpt;
/


GRANT EXECUTE ON ABC.GEN_REVPPART1_RPT TO POSSEEXTENSIONS;
