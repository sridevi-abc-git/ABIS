CREATE OR REPLACE FUNCTION BIZMOD_API.requestcateringdropdownlists(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCATERINGDROPDOWNLISTS.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   08/31/2023  TJL BIZ-12565   Initial Function Created
    -- ****************************************************************************
    t_effectivedate TIMESTAMP; -- DATE;
    t_object       json_object_t := NEW json_object_t();
    t_data         json_object_t;
    t_eventtypes   json_array_t := NEW json_array_t();
    t_cities       json_array_t := NEW json_array_t();
    t_fees         json_array_t := NEW json_array_t();
    t_tmp          json_object_t;
    t_tier         json_object_t;
BEGIN
    SELECT json_value(a_packet, '$.DATA.FEEDATE' RETURNING TIMESTAMP)
      INTO t_effectivedate
      FROM DUAL;

    t_object.put('PACKET_TYPE', 'CATERINGDROPDOWNS');
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
        IN (  SELECT fs.*, t.VALUE
                FROM (  SELECT fs.feetier, fs.secondaryamount, ROWNUM line
                          FROM sitespecific.feeschedule_t fs
                         WHERE fs.feeactivity = 'CATA'
                           AND fs.effectivedate =
                               (SELECT MAX(fs2.effectivedate)
                                  FROM sitespecific.feeschedule_t fs2
                                 WHERE NVL(fs2.licensetypecode, '0') =
                                       NVL(fs.licensetypecode, '0')
                                   AND fs2.feeactivity = fs.feeactivity
                                   AND fs2.feetier = fs.feetier
                                   AND fs2.effectivedate <= TRUNC(SYSDATE))
                      ORDER BY fs.feetier) fs
                     JOIN (  SELECT VALUE, lv
                               FROM (    SELECT TRIM(REGEXP_SUBSTR(ltc.maxtiercount,
                                                                   '[^,]+',
                                                                   1,
                                                                   LEVEL))    VALUE,
                                                LEVEL                         lv
                                           FROM query.o_licensetypecategory ltc
                                          WHERE ltc.licensetypecode = '58'
                                     CONNECT BY REGEXP_SUBSTR(ltc.maxtiercount,
                                                              '[^,]+',
                                                              1,
                                                              LEVEL)
                                                    IS NOT NULL)
                           GROUP BY VALUE, lv) t
                         ON lv = fs.line
            ORDER BY line)
    LOOP
        t_tier := NEW json_object_t();
        t_tier.put('AMOUNT', rec.secondaryamount);
        t_tier.put('MINATTENDANCE', rec.VALUE);
        t_tmp := NEW json_object_t();
        t_tmp.put(rec.feetier, t_tier);
        t_fees.append(t_tmp);
    END LOOP;

    t_data.put('FEES', t_fees);

    --    DBMS_OUTPUT.put_line(t_object.TO_CLOB);

    RETURN t_object.TO_CLOB;
END;
/
