CREATE OR REPLACE PROCEDURE SITESPECIFIC.tl_studentsearch(a_search       IN  VARCHAR2,
                                                          a_type         IN  VARCHAR2,
                                                          a_studentdata  OUT SYS_REFCURSOR,
                                                          a_msg          OUT VARCHAR2)
                    IS
    -- **************************************************************************
    -- File:        TL_STUDENTSEARCH.PRC  
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
    
        OPEN a_studentdata FOR
                SELECT ObjectId, 
                       studentname, 
                       emailaddress, 
                       attended, 
                       passed, 
                       confirmationnumber
                  FROM query.o_Tl_Studentregistration
                 WHERE 
                       (CASE
                           WHEN a_type = 'N' AND UPPER(studentname) LIKE '%' || UPPER(a_search) || '%' THEN 'TRUE'
                           WHEN a_type = 'C' AND confirmationnumber = a_search THEN 'TRUE'
                           WHEN a_type = 'E' AND UPPER(emailaddress) LIKE '%' || UPPER(a_search) || '%' THEN 'TRUE'
                           ELSE 'FALSE' END) = 'TRUE'
                 ORDER BY studentname;
    
    EXCEPTION
        WHEN OTHERS THEN
        
        null;
    END;
/


GRANT EXECUTE ON SITESPECIFIC.TL_STUDENTSEARCH TO POSSEEXTENSIONS;
