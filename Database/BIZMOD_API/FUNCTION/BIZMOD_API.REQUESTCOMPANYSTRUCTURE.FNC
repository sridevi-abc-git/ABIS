CREATE OR REPLACE FUNCTION BIZMOD_API.requestcompanystructure(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTCOMPANYSTRUCTURE.FNC
    -- Author:      Bhavya Nagaraja
    --
    -- Purpose : This function is used to return company structure list
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   10/01/2024  BN BIZ-16349   Initial Function Created
    -- ****************************************************************************
    t_object       json_object_t := NEW json_object_t();
    t_data         json_object_t;
    t_compStr       json_array_t := NEW json_array_t();
 BEGIN

    t_object.put('PACKET_TYPE', 'COMPANYSTRUCTURE');
    t_object.put('DATA', NEW json_object_t());
    t_data := t_object.get_object('DATA');

    FOR rec IN (  SELECT attributevalue
                    FROM api.domainlistofvalues 
                   WHERE domainid = 334440
                ORDER BY 1)
    LOOP
        t_compStr.append(rec.attributevalue);
    END LOOP;

    t_data.put('COMPANYSTRUCTURE', t_compStr);

    RETURN t_object.TO_CLOB;
END;
/