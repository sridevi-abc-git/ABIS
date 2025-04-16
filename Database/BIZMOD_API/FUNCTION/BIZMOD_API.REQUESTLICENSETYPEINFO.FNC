CREATE OR REPLACE FUNCTION BIZMOD_API.requestlicensetypeinfo(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTLICENSETYPEINFO.FNC
    -- Author:      Bhavya Nagaraja
    --
    -- Purpose :     return all the information of license types.
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   10/14/2024  BN BIZ-16357   Initial Function Created
    -- ****************************************************************************

    t_json_obj     json_object_t;
    t_json_arr     json_array_t := json_array_t();

    t_json_return     json_object_t := json_object_t();

    t_results      CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);

BEGIN

    FOR rec IN (  SELECT *
                    FROM query.o_licensetypecategory order by LICENSETYPECODE)
    LOOP
        t_json_obj := json_object_t();
        t_json_obj.put('LICENSETYPECODE',rec.LICENSETYPECODE);

        t_json_obj.put('LICENSETYPENAME',rec.LICENSETYPENAME);
        t_json_obj.put('MAXIMUMCOUNTSTRING',rec.MAXIMUMCOUNTSTRING);
        t_json_obj.put('PERMANENTPRIMARYALLOWED',rec.PERMANENTPRIMARYALLOWED);
        t_json_obj.put('SECONDARYLTSAPPLICABLE',rec.SECONDARYLTSAPPLICABLE);
        t_json_obj.put('SECONDARYLICENSETYPECODES',rec.SECONDARYLICENSETYPECODES);
        t_json_obj.put('SECONDARYOBJECTIDS',rec.SECONDARYOBJECTIDS);
        t_json_obj.put('GALLONAGEAPPLIES',rec.GALLONAGEAPPLIES);
        t_json_obj.put('INCLUDEINONSALEPRIORITYDRAWCOU',rec.INCLUDEINONSALEPRIORITYDRAWCOU);

        t_json_obj.put('ONEDAYLICENSE',rec.ONEDAYLICENSE);
        t_json_obj.put('POPULATIONAPPLIES',rec.POPULATIONAPPLIES);
        t_json_obj.put('PRIORITYDRAWLICENSETYPE',rec.PRIORITYDRAWLICENSETYPE);
        t_json_obj.put('RETAILTYPE',rec.RETAILTYPE);
        t_json_obj.put('SEASONALMONTHSAPPLY',rec.SEASONALMONTHSAPPLY);
        t_json_obj.put('SECONDARYONLY',rec.SECONDARYONLY);

        t_json_obj.put('COLOR',rec.COLOR);
        t_json_obj.put('BRANCHAPPLIES',rec.BRANCHAPPLIES);
        t_json_obj.put('PRIMARYCOUNTAPPLIES',rec.PRIMARYCOUNTAPPLIES);
        t_json_obj.put('APPLICATIONFEETYPE',rec.APPLICATIONFEETYPE);
        t_json_obj.put('ISACTIVE',rec.ISACTIVE);
        t_json_obj.put('CATEGORY',rec.CATEGORY);

        t_json_arr.append(t_json_obj);
    END LOOP;
    t_json_return.put('PACKET_TYPE', 'LICENSETYPEINFO');
    t_json_return.put('DATA', t_json_arr);

    RETURN t_json_return.TO_CLOB;
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;
 
        SELECT json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE 5,
                           'MSG' VALUE 'Oracle Exception',
                           'EXCEPTION' VALUE
                               REGEXP_REPLACE(t_msg, '[^[:print:]]', ' ')))
        INTO t_results
        FROM DUAL;

        RETURN t_results;
END;
/