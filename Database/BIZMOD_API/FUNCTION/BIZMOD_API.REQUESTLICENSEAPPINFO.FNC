CREATE OR REPLACE FUNCTION BIZMOD_API.REQUESTLICENSEAPPINFO(a_packet       IN CLOB,
                                                         a_seq          IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:    BIZMOD_API.REQUESTLICENSEAPPINFO.FNC
    -- Author:  Timothy J. Lord
    --
    -- History
    -------------------------------------------------------------------------------
    --  Ver:       Date          Ticket       Comment
    --   1.0   10/07/2024  TJL  BIZ-16424  Inital function created
    -- ****************************************************************************


    FUNCTION get_attorney(a_objectid IN NUMBER)
        RETURN json_object_t
    AS
        t_attorneyobjectid NUMBER;
        t_attorney     json_object_t := json_object_t();
    BEGIN
        SELECT r.toobjectid
          INTO t_attorneyobjectid
          FROM api.relationships r
         WHERE r.fromobjectid = a_objectid
           AND r.endpointid =
               api.pkg_configquery.endpointidforname(
                   api.pkg_columnquery.VALUE(a_objectid, 'ObjectDefName'),
                   'Attorney');


        t_attorney.put(
            'FIRSTNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FIRSTNAME'));
        t_attorney.put(
            'MIDDLENAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'MIDDLENAME'));
        t_attorney.put(
            'LASTNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'LASTNAME'));
        t_attorney.put(
            'FIRMNAME',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FIRMNAME'));
        t_attorney.put(
            'PHONENUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_attorneyobjectid, 'PHONENUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_attorney.put(
            'FAXNUMBER',
            REGEXP_REPLACE(
                api.pkg_columnquery.VALUE(t_attorneyobjectid, 'FAXNUMBER'),
                '(\d{3})(\d{3})(\d{4})',
                '(\1)\2-\3'));
        t_attorney.put(
            'EMAIL',
            api.pkg_columnquery.VALUE(t_attorneyobjectid, 'EMAIL'));

        t_attorney.put(
            'ADDRESS',
            bizmod_api.utl_licenseinfo.get_address(
                a_objectid  => t_attorneyobjectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_attorneyobjectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_attorney;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;

    FUNCTION get_escrow(a_objectid IN NUMBER)
        RETURN json_object_t
    AS
        t_escrowobjectid NUMBER;
        t_escrow       json_object_t := json_object_t();
    BEGIN
        SELECT r.toobjectid
          INTO t_escrowobjectid
          FROM api.relationships r
         WHERE r.fromobjectid =
               api.pkg_columnquery.numericvalue(a_objectid,
                                                'LatestIssuedApplicationId')
           AND r.endpointid =
               api.pkg_configquery.endpointidforname(
                   api.pkg_columnquery.VALUE(
                       api.pkg_columnquery.numericvalue(
                           a_objectid,
                           'LatestIssuedApplicationId'),
                       'ObjectDefName'),
                   'Escrow');

        t_escrow.put(
            'ESCROWCOMPANYNAME',
            api.pkg_columnquery.VALUE(t_escrowobjectid, 'EscrowCompanyName'));

        t_escrow.put(
            'ADDRESS',
            bizmod_api.utl_licenseinfo.get_address(
                a_objectid  => t_escrowobjectid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_escrowobjectid,
                                                  'ObjectDefName'),
                        'Address')));

        RETURN t_escrow;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_secondarylicensetypes(a_objectid IN NUMBER)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
        t_object       json_object_t;
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid objectid, r.relationshipid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_objectid,
                                                     'ObjectDefName'),
                           'LicTypeCatSecondary')
                   AND r.fromobjectid = a_objectid)
        LOOP
            t_object := json_object_t();

            t_object.put(
                'LICENSETYPECODE',
                api.pkg_columnquery.VALUE(rec.objectid, 'LICENSETYPECODE'));
            t_object.put(
                'PRIMARYCOUNT',
                api.pkg_columnquery.VALUE(rec.relationshipid, 'NewCount'));

            t_array.append(t_object);
        END LOOP;

        RETURN t_array;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;


    FUNCTION get_primarylicensetypes(a_objectid IN NUMBER)
        RETURN json_array_t
    AS
        t_array        json_array_t := json_array_t();
        t_object       json_object_t;
    BEGIN
        FOR rec
            IN (SELECT r.toobjectid     objectid
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname(
                           api.pkg_columnquery.VALUE(a_objectid,
                                                     'ObjectDefName'),
                           'LicenseType')
                   AND r.fromobjectid = a_objectid)
        LOOP
            t_object := json_object_t();
            t_object.put(
                'LICENSETYPECODE',
                api.pkg_columnquery.VALUE(rec.objectid, 'LicenseTypeCode'));
            t_object.put(
                'GALLONAGE',
                api.pkg_columnquery.VALUE(rec.objectid, 'GallonageRange'));
            t_object.put(
                'NUMBEROFMONTHSLICENSED',
                api.pkg_columnquery.VALUE(rec.objectid,
                                          'NumberOfMonthsLicensed'));
            t_object.put(
                'SEASONSTARTMONTH',
                api.pkg_columnquery.VALUE(rec.objectid, 'SeasonStartMonth'));
            t_object.put(
                'PRIMARYCOUNT',
                api.pkg_columnquery.VALUE(rec.objectid, 'PrimaryCount'));
            t_object.put(
                'MASTERLICENSE',
                api.pkg_columnquery.VALUE(rec.objectid,
                                          'MasterPLTLicenseNum'));
            t_object.put(
                'ISBRANCH',
                api.pkg_columnquery.VALUE(rec.objectid, 'IsBranchS'));
            t_object.put(
                'SECONDARYLICENSETYPES',
                get_secondarylicensetypes(a_objectid => rec.objectid));

            t_array.append(t_object);
        END LOOP;

        RETURN t_array;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
    END;
-- ******************************************************
--
--
-- ******************************************************
BEGIN
    DECLARE
        t_application  json_object_t := json_object_t();
        t_data         json_object_t := json_object_t();
        t_applicationjobid api.pkg_definition.udt_id;
        t_response     CLOB;
    BEGIN
    
            t_applicationjobid := json_value(a_packet, '$.*.OBJECTID' returning number);

        t_application.put('PACKET_TYPE', 'LICENSEAPPINFO');
        t_application.put('SOURCELICENSE', t_applicationjobid);
        t_application.put('DATA', t_data);
        t_data := t_application.get_object('DATA');

        t_data.put('LSPAPPLICATIONID',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'LSPID'));
        t_data.put(
            'APPLICATIONTYPE',
            api.pkg_columnquery.VALUE(t_applicationjobid, 'APPLICATIONTYPE'));
        t_data.put('DBA',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'DBA'));
        t_data.put('FELONY',
                   api.pkg_columnquery.VALUE(t_applicationjobid, 'FELONY'));
        t_data.put('UNDERCONSTRUCTION', 'N');
        t_data.put(
            'VIOLATION',
            api.pkg_columnquery.VALUE(t_applicationjobid, 'VIOLATION'));
        t_data.put(
            'LICENSEPURCHASEPRICE',
            api.pkg_columnquery.numericvalue(t_applicationjobid,
                                             'LICENSEPURCHASEPRICE'));

        t_data.put('PRIMARYLICENSETYPES',
                   get_primarylicensetypes(a_objectid => t_applicationjobid));

        t_data.put(
            'PREMISESADDRESS',
            bizmod_api.utl_licenseinfo.get_address(
                a_objectid  => t_applicationjobid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_applicationjobid,
                                                  'ObjectDefName'),
                        'Premises')));
        t_data.put(
            'MAILINGADDRESS',
            bizmod_api.utl_licenseinfo.get_address(
                a_objectid  => t_applicationjobid,
                a_endpoint  =>
                    api.pkg_configquery.endpointidforname(
                        api.pkg_columnquery.VALUE(t_applicationjobid,
                                                  'ObjectDefName'),
                        'MailingAddress')));

        t_data.put('ATTORNEY',
                   get_attorney(a_objectid => t_applicationjobid));
        t_data.put('ESCROW', get_escrow(a_objectid => t_applicationjobid));

        t_data.put(
            'LEGALENTITIES',
            bizmod_api.utl_licenseinfo.get_legalentity(a_objectid => t_applicationjobid));

        DBMS_OUTPUT.put_line(
            SUBSTR(
                json_query(t_application.TO_CLOB, '$' RETURNING CLOB PRETTY),
                1,
                32000));

        bizmod_api.utl_licenseinfo.clean(t_application);
        RETURN t_application.TO_CLOB;
    END;
END;
/
