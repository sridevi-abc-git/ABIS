CREATE OR REPLACE FUNCTION BIZMOD_API.requestcateringlists(a_packet       IN CLOB,
                                                a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCATERINGLISTS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   08/31/2023  TJL BIZ-12565   Initial Function Created
    -- ****************************************************************************
    t_effectivedate DATE;
    t_object       json_object_t := NEW json_object_t();
    t_data         json_object_t;
    t_eventtypes   json_array_t := NEW json_array_t();
    t_cities       json_array_t := NEW json_array_t();
    t_fees         json_array_t := NEW json_array_t();
    t_tmp          json_object_t;
BEGIN
    SELECT json_value(a_packet, '$.DATA.FEEDATE') INTO t_effectivedate FROM DUAL;
    
    t_object.put('PACKETYPE', 'CATERINGDROPDOWNS');
    t_object.put('DATA', NEW json_object_t());
    t_data := t_object.get_object('DATA');

    FOR rec IN (  SELECT attributevalue
                    FROM api.domainlistofvalues
                   WHERE domainid = 305110
                ORDER BY 1)
    LOOP
        t_eventtypes.append(rec.attributevalue);
    END LOOP;

    t_data.put('EVENTTYPES', t_eventtypes);

    FOR rec IN (  SELECT attributevalue
                    FROM possedata.objectcolumndata d
                   WHERE columndefid = 328470
                ORDER BY 1)
    LOOP
        t_cities.append(rec.attributevalue);
    END LOOP;

    t_data.put('CITIES', t_cities);

    FOR rec
        IN (  SELECT fs.feetier, fs.secondaryamount
                FROM sitespecific.feeschedule_t fs
               WHERE fs.feeactivity = 'CATA'
                 AND fs.effectivedate =
                     (SELECT MAX(fs2.effectivedate)
                        FROM sitespecific.feeschedule_t fs2
                       WHERE NVL(fs2.licensetypecode, '0') =
                             NVL(fs.licensetypecode, '0')
                         AND fs2.feeactivity = fs.feeactivity
                         AND fs2.feetier = fs.feetier
                         AND fs2.effectivedate <= nvl(t_effectivedate, trunc(sysdate)))
            ORDER BY fs.feetier)
    LOOP
        t_tmp := NEW json_object_t();
        t_tmp.put(rec.feetier, rec.secondaryamount);
        t_fees.append(t_tmp);
    END LOOP;

    t_data.put('FEES', t_fees);

    DBMS_OUTPUT.put_line(t_object.TO_CLOB);
    
    return t_object.to_clob;
END;
/
