CREATE OR REPLACE FUNCTION BIZMOD_API.requestcateringformoptions(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCATERINGFORMOPTIONS.FNC
    -- Author:      Joe Stark
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   10/30/2023  TJL BIZ-13208   Initial Function Created
    -- ****************************************************************************
    t_object       json_object_t := NEW json_object_t();
    t_data         json_object_t;
    t_eventtypes   json_array_t := NEW json_array_t();
    t_cities       json_array_t := NEW json_array_t();
    t_fees         json_array_t := NEW json_array_t();
    t_tmp          json_object_t;
    t_tier         json_object_t;
BEGIN

    t_object.put('PACKET_TYPE', 'CATERINGFORMOPTIONS');
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

    --    DBMS_OUTPUT.put_line(t_object.TO_CLOB);

    RETURN t_object.TO_CLOB;
END;
/
