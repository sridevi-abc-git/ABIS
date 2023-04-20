CREATE OR REPLACE PROCEDURE ABC.get_status(
    a_jobid        IN     api.pkg_definition.udt_id,
    a_status          OUT VARCHAR2,
    a_statusdt        OUT DATE)
IS
    -- **************************************************************************
    -- File:        GET_STATUS.PRC
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
    BEGIN
        SELECT js.effectivestartdate, js.statusname
          INTO a_statusdt, a_status
          FROM extension.jobstatuschange_t js
         WHERE js.jobid = a_jobid
           AND js.mostrecent = 'Y';
    EXCEPTION
        WHEN OTHERS THEN
            a_statusdt   := NULL;
            a_status     := NULL;
    END;
END;
/


GRANT EXECUTE ON ABC.GET_STATUS TO POSSEEXTENSIONS;
