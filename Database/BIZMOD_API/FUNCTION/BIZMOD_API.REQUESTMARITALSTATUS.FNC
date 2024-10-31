CREATE OR REPLACE FUNCTION BIZMOD_API.requestmaritalstatus(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTMARITALSTATUS.FNC
    -- Author:      Bhavya Nagaraja
    --
    -- Purpose : This function is used to return marital status list
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --    1.0   10/01/2024  BN BIZ-16349   Initial Function Created
    -- ****************************************************************************
    t_object       	  json_object_t := NEW json_object_t();
    t_data        	  json_object_t;
    t_maritalstatus   json_array_t := NEW json_array_t();
 BEGIN

    t_object.put('PACKET_TYPE', 'MARITALSTATUS');
    t_object.put('DATA', NEW json_object_t());
    t_data := t_object.get_object('DATA');
    
    dbms_output.put_line('inside ficntion');

    FOR rec IN ( SELECT attributevalue
                 FROM api.domainlistofvalues
                 WHERE domainid = 309076
                ORDER BY 1)
    LOOP
     dbms_output.put_line('value' || rec.attributevalue);
        t_maritalstatus.append(rec.attributevalue);
    END LOOP;

    t_data.put('MARITALSTATUS', t_maritalstatus);

    RETURN t_object.TO_CLOB;
END;
/