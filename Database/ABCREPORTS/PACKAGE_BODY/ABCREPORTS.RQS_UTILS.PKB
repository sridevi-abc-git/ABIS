CREATE OR REPLACE PACKAGE BODY ABCREPORTS.RQS_UTILS AS
-- ****************************************************************************
-- File:        rqs_utils_v2.pkb  
-- Author:      Timothy J. Lord
--
-- $Rev: 196 $  
-- $Date: 2019-01-10 09:00:28 -0800 (Thu, 10 Jan 2019) $
-- Last Changed By:  $Author: tlord $
--
-- Description: RPT_UTILS package specifications   
--
-- Functions:    
--
-- History:
-------------------------------------------------------------------------------
--    Date         Ticket     Comment
-- 09/16/2015 TJL       Original file created
-- 03/09/2016 TJL  9131 Corrected logging bug in job id not being lost
-- 08/02/2016 TJL 10121 Added TEU office type as valid office type to have 
--                      access to rqs reports.
-- 11/15/2016 TJL 10694 Added exclude filter check when generating office list
-- 07/23/2018 TJL 15828 Modified exclude filter in function BuildOfficeList
-- ****************************************************************************

FUNCTION to_base64(t IN VARCHAR2) RETURN VARCHAR2 IS

 BEGIN
    RETURN utl_raw.cast_to_varchar2(utl_encode.base64_encode(utl_raw.cast_to_raw(t)));
 END to_base64;


FUNCTION from_base64(t IN VARCHAR2) RETURN VARCHAR2 IS

 BEGIN
    RETURN utl_raw.cast_to_varchar2(utl_encode.base64_decode(utl_raw.cast_to_raw(t)));
 END from_base64;


FUNCTION BuildOfficeList(p_office_object_id IN     NUMBER,
                         p_status_msg       IN OUT VARCHAR2) 
            RETURN t_officeobject IS

    tbl_office          t_officeobject;
    cur                 SYS_REFCURSOR;
    lv_division         query.o_office.division%TYPE        := NULL;
    lv_isdistrict       query.o_office.isdistrict%TYPE; 
    lv_office_code      QUERY.o_office.officecode%TYPE;
    ln_id               query.o_office.objectid%TYPE        := NULL; 
    lv_exclude          VARCHAR2(1);    --07/23/2018 TJL WO15828
        
 BEGIN
    IF (p_office_object_id IS NOT NULL) THEN
        -- get devision for selected office and district flag
        SELECT division, isdistrict, officecode, NVL(rqsexclude, 'N')   --07/23/2018 TJL WO15828
          INTO lv_division, lv_isdistrict, lv_office_code, lv_exclude 
          FROM query.o_Office o 
         WHERE o.isactive = 'Y'
           AND o.objectid = p_office_object_id
         ORDER BY OfficeCode;

        -- check if request is from district
        IF ((lv_isdistrict = 'Y') OR (lv_exclude != 'N')) --07/23/2018 TJL WO15828
        THEN 
            ln_id := p_office_object_id;
        END IF;
    END IF;
        
    OPEN cur FOR 
        SELECT t_officeobjectrec(o.objectid, o.officename, o.officecode)
          FROM query.o_Office o 
         WHERE o.isactive = 'Y'
           AND o.objectid = NVL(ln_id, o.objectid)
           AND NVL(o.division, '*') = NVL(lv_division, NVL(o.division, '*'))
           AND (    
                    (ln_id IS NULL AND NVL(o.rqsexclude, '*') NOT IN ('H', 'B'))
                  OR ln_id IS NOT NULL 
               )
         ORDER BY o.officecode;
           
    -- retrive list of office object id's 
    FETCH cur BULK COLLECT INTO tbl_office LIMIT 60;
    CLOSE cur;

    RETURN tbl_office;
 
 EXCEPTION
    WHEN OTHERS THEN
        p_status_msg := 'BuildOfficeList(EXCEPTION): ' 
                     || dbms_utility.format_error_backtrace
                     || ' :: ' || SQLERRM;
        RETURN NULL;
 END BuildOfficeList;
                       

FUNCTION BuildOfficeCodeList(p_office IN VARCHAR2) 
            RETURN t_officeobject IS

    tbl_office          t_officeobject;
    cur                 SYS_REFCURSOR;
    lv_division         query.o_office.division%TYPE        := NULL;
    lv_isdistrict       query.o_office.isdistrict%TYPE; 
    lv_office_code      QUERY.o_office.officecode%TYPE;
    ln_id               NUMBER                              := NULL;
    ln_objectid         NUMBER;
        
 BEGIN
    IF (p_office IS NOT NULL) THEN
        -- get devision for selected office and district flag
        SELECT division, isdistrict, officecode, objectid
          INTO lv_division, lv_isdistrict, lv_office_code, ln_objectid
          FROM query.o_Office o 
         WHERE o.isactive = 'Y'
           AND UPPER(o.office) = UPPER(p_office)
         ORDER BY OfficeCode;

        -- check if request is from district
        IF ((lv_isdistrict = 'Y') OR 
            -- Licensing, TEU, SOU South, SOU North, gap southern, gap norther
            (ln_objectid IN (5531, 5536, 5538, 5539, 75598452, 75586813)))
        THEN 
            ln_id := ln_objectid;
        END IF;
    END IF;
        
    OPEN cur FOR 
        SELECT t_officeobjectrec(o.objectid, o.officename, o.officecode)
          FROM query.o_Office o 
         WHERE o.isactive = 'Y'
           AND o.objectid = NVL(ln_id, o.objectid)
           AND NVL(o.division, '*') = NVL(lv_division, NVL(o.division, '*'))
           AND (    
                    (ln_id IS NULL AND NVL(o.rqsexclude, '*') NOT IN ('H', 'B'))
                  OR ln_id IS NOT NULL 
               )
         ORDER BY o.officecode;
           
    -- retrive list of office object id's 
    FETCH cur BULK COLLECT INTO tbl_office LIMIT 40;
    CLOSE cur;

    RETURN tbl_office;
 
-- EXCEPTION
--    WHEN OTHERS THEN
--        p_status_msg := 'BuildOfficeCodeList (EXCEPTION): ' 
--                     || dbms_utility.format_error_backtrace
--                     || ' :: ' || SQLERRM;
--        RETURN NULL;
 END BuildOfficeCodeList;
                       

FUNCTION cursor_to_xml (p_cursor        IN     SYS_REFCURSOR,
                        p_rowset_name   IN     VARCHAR2,
                        p_row_name      IN     VARCHAR2,
                        p_status_msg    IN OUT VARCHAR2) 
            RETURN XMLTYPE IS

    retval      XMLTYPE;
    ctx         dbms_xmlgen.ctxHandle;
    
    begin
       ctx := dbms_xmlgen.newContext (p_cursor);
       
       dbms_xmlgen.setRowTag (ctx, p_row_name);
       dbms_xmlgen.setRowSetTag (ctx, p_rowset_name);
       
       retval := dbms_xmlgen.getXMLType (ctx);
       dbms_xmlgen.closeContext (ctx);
       
       return retval;
       
    EXCEPTION
        WHEN OTHERS THEN
            p_status_msg := 'cursor_to_xml(EXCEPTION): ' 
                        || dbms_utility.format_error_backtrace
                        || ' :: ' || SQLERRM;
            RETURN NULL;
    end cursor_to_xml;



PROCEDURE log(p_log_type          IN  VARCHAR2,
              p_job_id            IN  VARCHAR2,
              p_seq               IN  VARCHAR2,
              p_source            IN  VARCHAR2,
              p_msg               IN  VARCHAR2,
              p_additional_data   IN  VARCHAR2 := NULL,
              p_error_trace       IN  VARCHAR2 := NULL) IS

    ln_job_id       NUMBER      := p_job_id;
    ln_seq          NUMBER;
    
 BEGIN
    IF (p_job_id IS NULL AND p_seq IS NOT NULL) THEN
        SELECT job_id 
          INTO ln_job_id
          FROM report_xref 
         WHERE seq = p_seq;
    END IF;
    
    IF ((UPPER(NVL(RQS_UTILS.GET_CTRL_VALUE('LOG_TRACE'), 'N')) = 'T') OR
        (UPPER(p_log_type) = 'E')) THEN 
        INSERT INTO report_error_log
                   (log_type_ind,
                    job_id,
                    seq,
                    src,   
                    msg,    
                    additional_data,            
                    error_trace)                                    
            VALUES (p_log_type,
                    ln_job_id, 
                    p_seq,
                    SUBSTR(p_source, 1, 200),
                    SUBSTR(p_msg, 1, 4000),
                    SUBSTR(p_additional_data, 1, 4000),
                    SUBSTR(p_error_trace, 1, 4000));
    END IF;

    COMMIT;
    -- delete all record beond 1000
    DELETE report_error_log 
     WHERE log_seq < (SELECT MIN(log_seq) 
                        FROM (SELECT log_seq
                                FROM report_error_log 
                               ORDER BY log_seq DESC)
                       WHERE rownum < 20000);
 
    COMMIT;
                        
 -- do nothing on errors when cannot update error log table                                              
 EXCEPTION WHEN OTHERS THEN 
    DBms_output.put_line(SQLERRM);
    DBms_output.put_line(p_msg);
    DBms_output.put_line(p_additional_data);
    
 END log;

                                             
FUNCTION get_ctrl_value(p_name IN VARCHAR2) RETURN VARCHAR2 IS
    lv_value    report_ctrl_parameters.parameter_value%TYPE;
    
    BEGIN
        SELECT parameter_value
          INTO lv_value
          FROM report_ctrl_parameters
         WHERE parameter_name = UPPER(p_name)
           AND ROWNUM = 1;
       
        RETURN lv_value;
                
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            lv_value := NULL;
            RETURN lv_value;        
            
        WHEN OTHERS THEN
            lv_value := NULL;
            RETURN lv_value;        
    END get_ctrl_value;
                                             

FUNCTION officelist(p_userobjectid IN NUMBER) RETURN VARCHAR2 IS

    lv_officelist       VARCHAR2(4000);
    lv_list             VARCHAR2(4000);
    lv_officeobjectid   NUMBER;
    lv_division         VARCHAR2(20);
    lv_isdistrict       VARCHAR2(1);
    lv_officetype       VARCHAR2(100);
    
    BEGIN
        -- get user office
        SELECT api.pkg_columnquery.VALUE(p_userobjectid, 'OfficeObjectId') officeid INTO lv_officeobjectid FROM DUAL;
        
        -- get information about office
        SELECT division, isdistrict, officetype
          INTO lv_division, lv_isdistrict, lv_officetype
          FROM query.o_office
         WHERE objectid = lv_officeobjectid;

        IF ((UPPER(lv_isdistrict) = 'Y') 
            OR (UPPER(lv_officetype)= 'TEU') 
            OR (UPPER(lv_officetype) LIKE 'SOU%')) 
        THEN
--            SELECT api.pkg_columnquery.VALUE(p_userobjectid, 'OfficeIdList') officeid INTO lv_list FROM DUAL;
            SELECT LISTAGG (officename, ',') WITHIN GROUP (ORDER BY officename) --(ORDER BY objectid)
              INTO lv_list
              FROM (SELECT api.pkg_columnquery.VALUE(str, 'Officename') officename
                      FROM (SELECT DISTINCT TRIM(REGEXP_SUBSTR(str, '[^,]+', 1, LEVEL)) str
                      FROM (SELECT api.pkg_columnquery.VALUE(p_userobjectid, 'OfficeidList') str FROM DUAL)
                   CONNECT BY INSTR(str, ',', 1, LEVEL - 1) > 0));                                                 
        ELSIF (UPPER(lv_officetype) = 'HEADQUARTERS') THEN
            SELECT listagg (officename, ',') WITHIN GROUP (ORDER BY officename) --(ORDER BY objectid)
            INTO lv_list
            FROM query.o_office
            WHERE (UPPER(lv_officetype) = 'HEADQUARTERS'
                   OR UPPER(NVL(officetype, 'DIVISION')) = 'DIVISION'  
                   OR isdistrict = 'Y')
              AND isactive = 'Y';
        ELSE -- must be division
            SELECT listagg (officename, ',') WITHIN GROUP (ORDER BY officename) --(ORDER BY objectid)
            INTO lv_list
            FROM query.o_office
            WHERE (objectid = lv_officeobjectid 
                   OR division = lv_division)
              AND isactive = 'Y';
        END IF;
                    
        SELECT 
            (SELECT '{"OFFICEOBJECTID":"' || api.pkg_columnquery.VALUE(p_userobjectid, 'OfficeObjectId') || '","'
                         || 'ISDISTRICT":"' || lv_isdistrict || '","'
                         || 'OFFICETYPE":"' || lv_officetype || '","'
                         || 'DIVISION":"' || lv_division || '","'
                         || 'OFFICE_LIST'   || '":[' || LISTAGG('{"OFFICEOBJECTID":"' || (Select objectid from query.o_office where officename = str) 
                                                            || '","OFFICENAME":"' || str --api.pkg_columnquery.VALUE(str, 'Officename') 
                                                            || '","ISDISTRICT":"' ||
                                                                    CASE TO_CHAR((SELECT objectid FROM query.o_office WHERE officename = str))
                                                                        WHEN '5536' THEN 'Y'      -- TEU
                                                                        WHEN '5539' THEN 'Y'      -- SOU South
                                                                        WHEN '75598452' THEN 'Y'  -- GAP South
                                                                        WHEN '5538' THEN 'Y'      -- SOU North
                                                                        WHEN '75586813' THEN 'Y'  -- GAP North
                                                                        WHEN '5531' THEN 'Y'      -- Licensing
                                                                        ELSE api.pkg_columnquery.VALUE((SELECT objectid
                                                                                                          FROM query.o_office
                                                                                                         WHERE officename = str), 'IsDistrict')                                                                   END 
                                                            ||'"}', ',')
             WITHIN GROUP (ORDER BY str) || ']}' "parms"
               FROM (SELECT DISTINCT trim(regexp_substr(str, '[^,]+', 1, LEVEL)) str
               FROM (select lv_list str from dual)
            CONNECT BY instr(str, ',', 1, LEVEL - 1) > 0))
        INTO lv_officelist
        FROM DUAL;        
    
        RETURN NVL(lv_officelist, 'empty');    
    END;

FUNCTION countylist
    RETURN VARCHAR2
IS
    lv_countylist   VARCHAR2(4000);
BEGIN
    WITH
        counties
        AS
            (SELECT    '{"COUNTYNAME":"'
                    || c.countyname
                    || '","COUNTYCODE":"'
                    || c.countycode
                    || '"}'
                        county
               FROM mart.cacounty c)
    SELECT    '"COUNTIES":['
           || (SELECT LISTAGG(c.county, ',') WITHIN GROUP (ORDER BY c.county) counties
                 FROM counties c)
           || ']'
      INTO lv_countylist
      FROM DUAL;
      
    RETURN lv_countylist;
END;


PROCEDURE userinfo(p_oracleLogonId  IN  VARCHAR2,
                   p_connection     IN  VARCHAR2,
                   p_data           OUT VARCHAR2,
                   p_status_msg     OUT VARCHAR2) IS
                   
    BEGIN
             
    SELECT '{"USEROBJECTID":"'  || objectid || '",' || 
           '"USER_NAME":"'      || api.pkg_columnquery.VALUE(objectid, 'FormattedUserName') || '",' ||
           '"EMAIL_TO":"'       || REGEXP_SUBSTR(api.pkg_columnquery.VALUE(objectid, 'eMailAddress'), '[^@]*') || '",' ||
           '"ORACLELOGONID":"'  || OracleLogonId || '",' ||
           '"OFFICEOBJECTID":"' || api.pkg_columnquery.VALUE(objectid, 'OfficeObjectId') || '",' ||
           '"OFFICENAME":"'     || api.pkg_columnquery.VALUE(objectid, 'Officename') || '",' || 
           '"CONNECTION":"'     || p_connection || '",' || 
           '"USER_ROLE_IND":"'  || ur.user_role_ind || '"}'
      INTO p_data
      FROM possedata.readableobjects
           INNER JOIN admin.users e ON e.userid = objectid
           INNER JOIN abcreports.rqs_user_role ur ON e.userid = ur.user_id
     WHERE objectdefid = api.pkg_configquery.objectdefidforname('Users')
       AND UPPER(e.oraclelogonid) = UPPER(p_oraclelogonid);


    EXCEPTION 
        WHEN NO_DATA_FOUND THEN
            p_status_msg := 'Sorry but you do not have access to the Report Query System.'
                         || CHR(13) || CHR(10) 
                         || 'Please contact your supervisor to get access.'; 
        WHEN OTHERS THEN
            p_status_msg := 'BuildOfficeList(EXCEPTION): ' 
                         || dbms_utility.format_error_backtrace
                         || ' :: ' || SQLERRM;
    END userinfo;


PROCEDURE search(p_search        IN  XMLTYPE,
                 p_data          OUT SYS_REFCURSOR,
                 p_status_msg    OUT VARCHAR2) IS
 
    lt_search           t_parameters;
    lv_search_by        VARCHAR2(1);
    ln_OfficeObjectId   NUMBER      := NULL;
         
 BEGIN
    -- get search parameter from xml
    lt_search := t_parameters(p_search);

    -- get user role
    if (NVL(lt_search.get_value('USER_ROLE_IND'), 'U') != 'I') THEN 
         --get office id
        ln_OfficeObjectId := TO_NUMBER(NVL(lt_search.get_value('OFFICEOBJECTID'), '0'));
    END IF;
    
    lv_search_by := NVL(lt_search.get_value('SEARCH_BY'), 'N');
            
    OPEN p_data FOR
            SELECT *
              FROM v_user_search
             WHERE 
                   (CASE
                       WHEN lv_search_by = 'N' AND UPPER(user_name) LIKE '%' || UPPER(lt_search.get_value('value')) || '%' THEN 'TRUE'
                       WHEN lv_search_by = 'U' AND UPPER(oraclelogonid) LIKE '%' || UPPER(lt_search.get_value('value')) || '%' THEN 'TRUE'
                       WHEN lv_search_by = 'E' AND UPPER(emailaddress) LIKE '%' || UPPER(lt_search.get_value('value')) || '%' THEN 'TRUE'
                       ELSE 'FALSE' END) = 'TRUE'
               AND OfficeObjectId = NVL(ln_OfficeObjectId, OfficeObjectId)
             ORDER BY user_name;
 EXCEPTION
    WHEN OTHERS THEN
        p_status_msg := 'RQS_USER.SEARCH(EXCEPTION): ' 
                     || dbms_utility.format_error_backtrace
                     || ' :: ' || SQLERRM;

END search;


PROCEDURE available_reports(p_userobjectid  IN  NUMBER,
                            p_data          OUT SYS_REFCURSOR,
                            p_status_msg    OUT VARCHAR2) IS

 BEGIN
    OPEN p_data FOR
        SELECT rd.report_name,
               rd.report_number, 
               CASE NVL(rr.report_number, 0) 
                    WHEN 0 THEN 'N' 
                    ELSE 'Y' 
               END "ACCESS"
--               'Y' "ACCESS"
          FROM report_def rd
         INNER JOIN rqs_report_def_access ra
            ON (rd.report_number = ra.rpt_id)
          LEFT OUTER JOIN user_reports rr
            ON (rd.report_number = rr.report_number AND userobjectid = p_userobjectid )
         WHERE ra.access_ind =
                    (SELECT 
                            CASE NVL(v.VALUE, '*') 
                                   WHEN 'HEADQUARTERS'                  THEN 'H' 
                                   WHEN 'DISTRICT'                      THEN 'O' 
                                   WHEN 'DIVISION'                      THEN 'D' 
                                   WHEN 'TEU'                           THEN 'H'
                                   WHEN 'SOU (SPECIAL OPERATIONS UNIT)' THEN 'D' 
                                   ELSE '' 
                            END
                       FROM possedata.objectcolumndata d
                       LEFT OUTER JOIN objmodelphys.alldomainlistofvalues v
                         ON v.listvalueid = d.attributevalueid
                      WHERE d.objectid = (SELECT api.pkg_columnquery.VALUE(p_userobjectid, 'OfficeObjectId') FROM DUAL)
                        AND d.columndefid = 296235)
           AND rd.web_flg = 'Y'
         ORDER BY rd.report_name;

 EXCEPTION
    WHEN OTHERS THEN
        p_status_msg := 'RQS_USER.INFO(EXCEPTION): ' 
                     || dbms_utility.format_error_backtrace
                     || ' :: ' || SQLERRM;
 END available_reports;

    


PROCEDURE upduser(p_userobjectid  IN  NUMBER,
                  p_user_role     IN  VARCHAR2,
                  p_report_list   IN  XMLTYPE,
                  p_status_msg    OUT VARCHAR2,
                  p_return_code   OUT NUMBER) IS
 
    TYPE rec_t  IS RECORD (
                            DELETE_RPT      VARCHAR2(1),
                            USEROBJECTID    NUMBER,
                            REPORT_NUMBER   NUMBER
                           );
         
    lc_         SYS_REFCURSOR;
    lr_         rec_t;
    ln_cnt      NUMBER;
                  
 BEGIN
    IF (LENGTH(NVL(p_user_role, '')) > 0) THEN
        -- check to see if user id alread exists in role table
        SELECT NVL(count(*), 0)
          INTO ln_cnt
          FROM rqs_user_role ur
         WHERE ur.user_id = p_userobjectid;
        
        IF (ln_cnt = 0) THEN
            -- insert new record
            INSERT INTO rqs_user_role ur
                       ( ur.user_id,
                         ur.user_role_ind
                       )
                VALUES ( p_userobjectid,
                         p_user_role
                       );
                       
        ELSE
            -- update current record
            UPDATE rqs_user_role ur
               SET user_role_ind = p_user_role,
                   ur.update_date = SYSDATE,
                   ur.updated_by = user
             WHERE user_id = p_userobjectid;
            
        END IF;
        
        IF (SQL%ROWCOUNT = 0) THEN
            -- record not updated or added
            p_return_code := 1;
            
            IF (ln_cnt = 0) THEN
                p_status_msg := 'User not added';
            ELSE
                p_status_msg := 'User record not updated';
            END IF;
        ELSE
            -- record added or updated
            IF (ln_cnt = 0) THEN
                p_status_msg := 'User added';
            ELSE
                p_status_msg := 'User record updated';
            END IF;
        END IF;

        IF (p_report_list IS NOT NULL) THEN
            OPEN lc_ FOR SELECT delete_rpt, userobjectid, report_number
                           FROM XMLTABLE('/*/*'
                                 PASSING p_report_list
                                 COLUMNS delete_rpt     VARCHAR2(1) PATH 'DELETE_RPT',
                                         userobjectid   NUMBER      PATH 'USEROBJECTID',
                                         report_number  NUMBER      PATH 'REPORT_NUMBER'
                                         );
            LOOP                      
                FETCH lc_ INTO lr_;
                EXIT WHEN lc_%NOTFOUND;                          
                -- check if to delete
                IF (lr_.delete_rpt = 'Y') THEN
                    DELETE user_reports
                     WHERE userobjectid = lr_.userobjectid
                       AND report_number = lr_.report_number;
                ELSE
                    INSERT INTO user_reports
                           (userobjectid, 
                            report_number
                           )
                    VALUES (lr_.userobjectid,
                            lr_.report_number
                           );
                END IF;            
            END LOOP;
        END IF;
    ELSE
        -- delete user when user role is null or zero length
        DELETE rqs_user_role WHERE user_id = p_userobjectid;
        IF (SQL%ROWCOUNT = 0) THEN
            p_return_code := 1;
            p_status_msg := 'User not deleted';
        ELSE
            p_status_msg := 'User deleted';
        END IF;
    END IF;

                     
 EXCEPTION
    WHEN OTHERS THEN
        p_status_msg := 'RQS_USER.UPDUSER(EXCEPTION): ' 
                     || dbms_utility.format_error_backtrace
                     || ' :: ' || SQLERRM;
        p_return_code := SQLCODE;

END upduser;



FUNCTION report_info_json(p_report_number IN NUMBER) RETURN VARCHAR2 IS

    lv_results      VARCHAR2(200);
    
    BEGIN
        SELECT '"REPORT_NUMBER":"'   || report_number || 
               '","REPORT_NAME":"'   || report_name   ||
               '","BY_OFFICE_FLG":"' || by_office_flg || '"'
          INTO lv_results
          FROM report_def 
          WHERE report_number = p_report_number;
           
        RETURN lv_results;
        
    END report_info_json;
    
    
PROCEDURE GetSocketInfo(p_data OUT NUMBER) IS
                            
    BEGIN
        SELECT parameter_value
          INTO p_data
          FROM report_ctrl_parameters
         WHERE parameter_name = 'WND_SERVICE_PORT'; 
    
    
    END GetSocketInfo;                            

FUNCTION clob2blob(p_clob IN CLOB) RETURN BLOB IS

    blob_           BLOB;
    ln_pos          PLS_INTEGER     := 1;
    buffer          RAW( 32767 );
    ln_lob_len      PLS_INTEGER     := DBMS_LOB.getLength( p_clob );
    ln_len          NUMBER          := 32000;
    
    BEGIN
        DBMS_LOB.createTemporary( blob_, TRUE );
        DBMS_LOB.OPEN( blob_, DBMS_LOB.LOB_ReadWrite );

        LOOP
            buffer := UTL_RAW.cast_to_raw( DBMS_LOB.SUBSTR( p_clob, ln_len, ln_pos ) );

            IF UTL_RAW.LENGTH( buffer ) > 0 THEN
                DBMS_LOB.writeAppend( blob_, UTL_RAW.LENGTH( buffer ), buffer );
            END IF;

            ln_pos := ln_pos + ln_len;
            EXIT WHEN ln_pos > ln_lob_len;
        END LOOP;
        
        RETURN blob_;
    END clob2blob;
    
END RQS_UTILS;
/


CREATE OR REPLACE PUBLIC SYNONYM RQS_UTILS FOR ABCREPORTS.RQS_UTILS;


GRANT EXECUTE ON ABCREPORTS.RQS_UTILS TO ABCREPORTS_ROLE;
