CREATE OR REPLACE PROCEDURE ABC.tl_districtlist(
    p_districtlist OUT SYS_REFCURSOR)
IS
    -- **************************************************************************
    -- File:        TL_DISTRICTLIST.PRC
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
    -- 08/21/2018 TJL         Initial Check-in
    -- **************************************************************************
BEGIN
    OPEN p_districtlist FOR   SELECT o.office, objectid officeobjectid
                                FROM query.o_office o
                               WHERE o.isdistrict = 'Y'
                                 AND o.isactive = 'Y'
                            ORDER BY o.office;
END tl_districtlist;
/


GRANT EXECUTE ON ABC.TL_DISTRICTLIST TO POSSEEXTENSIONS;
