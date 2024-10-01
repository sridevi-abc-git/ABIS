create or replace FUNCTION requestcountrylist(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCOUNTRYLIST.FNC
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
    t_countrylist   json_array_t := NEW json_array_t();

BEGIN

    t_object.put('PACKET_TYPE', 'COUNTRYLIST');
    t_object.put('DATA', NEW json_object_t());
    t_data := t_object.get_object('DATA');

    FOR rec IN (  SELECT attributevalue
                    FROM api.domainlistofvalues
                   WHERE domainid = 301955
                ORDER BY 1)
    LOOP
        t_countrylist.append(rec.attributevalue);
    END LOOP;

    t_data.put('COUNTRYLIST', t_countrylist);

    RETURN t_object.TO_CLOB;
END;
/