create or replace FUNCTION requestcaliforniacities(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCALIFORNIACITIES.FNC
    -- Author:      Bhavya Nagaraja
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   06/25/2024  BN BIZ-15363   Initial Function Created
    -- ****************************************************************************
    t_object       json_object_t := NEW json_object_t();
    t_data         json_object_t;    
    t_cities       json_array_t := NEW json_array_t();
 BEGIN

    t_object.put('PACKET_TYPE', 'CALIFORNIACITIES');
    t_object.put('DATA', NEW json_object_t());
    t_data := t_object.get_object('DATA');

    FOR rec IN (  SELECT attributevalue
                    FROM possedata.objectcolumndata d
                   WHERE columndefid = 328470
                ORDER BY 1)
    LOOP
        t_cities.append(rec.attributevalue);
    END LOOP;

    t_data.put('CITIES', t_cities);

    RETURN t_object.TO_CLOB;
END;
/