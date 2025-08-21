CREATE OR REPLACE FUNCTION BIZMOD_API.requestvalidation(a_packet       IN CLOB,
                                             a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        REQUESTVALIDATION.FNC
    -- Author:      Timothy J. Lord
    --
    -- History:
    -------------------------------------------------------------------------------
    --            Date              Comment
    --         01/17/2023 TJL             Rewrite of original requestvalidation function 
    --                                      to use the Oracle json_object to create 
    --                                      JSON string
    --  2.0.0  03/10/2025 TJL  BIZ-17672  Increased buffer length to 4000
    -- ****************************************************************************
    t_objectid     NUMBER;
    t_licensenumber VARCHAR2(4000);
    t_validationcode VARCHAR2(4000);
    t_cnt          NUMBER;
    t_json         CLOB;
BEGIN
    t_licensenumber := json_value(a_packet, '$.*.LICENSENUMBER');
    t_validationcode := json_value(a_packet, '$.*.VALIDATIONCODE');

    -- get license object id by license number
    t_objectid :=
        api.pkg_simplesearch.objectbyindex('j_License',
                                           'ExternalFileNum',
                                           t_licensenumber);

    -- Make sure that only licenses with at least one active
    --   license type are validated.
    SELECT COUNT(1)
      INTO t_cnt
      FROM api.relationships r
     WHERE r.endpointid =
           api.pkg_configquery.endpointidforname('j_License', 'LicenseType')
       AND r.fromobjectid = t_objectid
       AND api.pkg_columnquery.VALUE(r.toobjectid, 'StatusName') IN
               ('ACTIVE',
                'REVPEN',
                'SUREND',
                'R64B',
                'SLMSHD',
                'SUSPEN');

    IF (t_validationcode =
        api.pkg_columnquery.VALUE(t_objectid, 'ValidationCode')
    AND t_cnt > 0)
    THEN
        SELECT json_object(
                   'PACKET_TYPE' VALUE 'VALIDATIONINFO',
                   'DATA' VALUE
                       json_object(
                           'LICENSEJOBID' VALUE t_objectid,
                           'LICENSENUMBER' VALUE t_licensenumber,
                           'VALIDATIONCODE' VALUE t_validationcode,
                           'CREATEDDATE' VALUE
                               api.pkg_columnquery.datevalue(
                                   t_objectid,
                                   'ValidationCodeCreatedDate'),
                           'STATUS' VALUE
                               api.pkg_columnquery.VALUE(t_objectid,
                                                         'StatusName')))
          INTO t_json
          FROM DUAL;
    ELSE
        t_json :=
            '{"PACKET_TYPE":"MESSAGE","DATA":{"MSGNO":"6","MSG":"License Number '
            || t_licensenumber
            || ' Not Found or Invalid validation code"}}';
    END IF;

    RETURN t_json;
END requestvalidation;
/
