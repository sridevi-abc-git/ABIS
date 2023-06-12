    CREATE OR REPLACE FUNCTION requestlicenseinfo(a_packet       IN CLOB,
                                                  a_seq          IN NUMBER)
        RETURN CLOB
    IS
    -- ****************************************************************************
    -- File:        REQUESTLICENSEINFO.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to return
    --              license information. A JSON packet with an array of License
    --              Object ids is passed into this function to select which
    --              license lnformation will be returned in a JSON packet.
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date           Ticket     Comment
    --  05/09/2022 TJL  BIZ-6500  Initial Function Created
    --  01/26/2023 TJL  BIZ-6500  Rewrite to generate JSON using json objects in 19C
    -- ****************************************************************************

    -- ****************************************************************************
    -- This procedure is called to remove any json elements that are null
    -- ****************************************************************************
--    PROCEDURE clean(a_json IN OUT json_object_t)
--    IS
--        t_json         json_object_t;
--        t_array        json_array_t;
--        t_element      json_element_t;
--        keys           json_key_list;
--    BEGIN
--        IF (a_json IS NOT NULL)
--        THEN
--            keys := a_json.get_keys;
--
--            IF (keys.COUNT > 0)
--            THEN
--                FOR i IN 1 .. keys.COUNT
--                LOOP
--                    IF (a_json.get_type(keys(i)) = 'ARRAY')
--                    THEN
--                        t_array := a_json.get_array(keys(i));
--
--                        IF (t_array.get_size = 0)
--                        THEN
--                            a_json.remove(keys(i));
--                        ELSE
--                            FOR pos IN 0 .. t_array.get_size - 1
--                            LOOP
--                                t_element := t_array.get(pos);
--
--                                IF (t_element.is_object)
--                                THEN
--                                    t_json :=
--                                        TREAT(t_element AS json_object_t);
--                                END IF;
--
--                                clean(a_json => t_json);
--                            END LOOP;
--                        END IF;
--                    ELSE
--                        t_json := a_json.get_object(keys(i));
--
--                        IF (t_json IS NOT NULL)
--                        THEN
--                            clean(a_json => t_json);
--                        ELSE
--                            IF (a_json.get_string(keys(i)) IS NULL)
--                            THEN
--                                a_json.remove(keys(i));
--                            END IF;
--                        END IF;
--                    END IF;
--                END LOOP;
--            END IF;
--        END IF;
--    END;

    FUNCTION getentityinfo(a_objectid IN NUMBER)
        RETURN CLOB
    IS
        lst            api.udt_objectlist := api.udt_objectlist();
        t_tbl          clob_tbl := clob_tbl();
        t_packet       CLOB;
        t_license      NUMBER;
    BEGIN
        t_license :=
            CASE (api.pkg_columnquery.VALUE(a_objectid, 'objectdefname'))
                WHEN 'o_LegalEntity' THEN 0
                ELSE 1
            END;

        SELECT api.udt_object(toobjectid)
          BULK COLLECT INTO lst
          FROM (SELECT DISTINCT r.toobjectid
                  FROM api.relationships r
                 WHERE api.pkg_columnquery.VALUE(r.toobjectid, 'ObjectDefId') =
                       295282 -- ('o_LegalEntity')
                   AND r.fromobjectid = a_objectid
                   AND (t_license = 1
                     OR r.fromobjectid =
                        api.pkg_columnquery.VALUE(r.toobjectid,
                                                  'dup_ParentObjectId')));

        FOR ind IN 1 .. lst.COUNT
        LOOP
            t_tbl.EXTEND(1);
            t_tbl(t_tbl.COUNT) := getentityinfo(lst(ind).objectid);
        END LOOP;

        SELECT json_arrayagg(VALUE(e) FORMAT JSON)
          INTO t_packet
          FROM TABLE(t_tbl) e;

        IF (t_license = 0)
        THEN
            t_packet :=
                CASE
                    WHEN t_packet IS NULL
                    THEN
                        json_object(
                            'LEGALENTITYTYPE' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LegalEntityType'),
                            'LESTRUCTUREREL' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LEStructureRel'),
                            'NAME' VALUE
                                api.pkg_columnquery.VALUE(
                                    a_objectid,
                                    'dup_FormattedName'),
                            'TITLE' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LETreeViewTitle'),
                            'LEVEL' VALUE
                                api.pkg_columnquery.VALUE(
                                    a_objectid,
                                    'dup_HierarchyLevel'),
                            'OBJECTID' VALUE a_objectid)
                    ELSE
                        json_object(
                            'LEGALENTITYTYPE' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LegalEntityType'),
                            'LESTRUCTUREREL' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LEStructureRel'),
                            'NAME' VALUE
                                api.pkg_columnquery.VALUE(
                                    a_objectid,
                                    'dup_FormattedName'),
                            'TITLE' VALUE
                                api.pkg_columnquery.VALUE(a_objectid,
                                                          'LETreeViewTitle'),
                            'LEVEL' VALUE
                                api.pkg_columnquery.VALUE(
                                    a_objectid,
                                    'dup_HierarchyLevel'),
                            'OBJECTID' VALUE a_objectid,
                            'CHILDENTITY' VALUE t_packet FORMAT JSON)
                END;
        END IF;

        RETURN t_packet;
    END;

    -- ****************************************************************************
    --  CONDITIONS
    -- ****************************************************************************
    FUNCTION conditions(t_licensejobid NUMBER, t_licensetypejobid NUMBER)
        RETURN CLOB
    IS
        t_cond_desc    CLOB;
    BEGIN
        WITH l AS(SELECT t_licensejobid, t_licensetypejobid FROM DUAL)
        SELECT json_array(
                   CASE api.pkg_columnquery.VALUE(t_licensejobid, 'CONDAV')
                       WHEN 'Y' THEN 'LIMITED ALIEN VERIFICATION DATE'
                       ELSE NULL
                   END, --    condav,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND1C')
                       WHEN 'Y'
                       THEN
                           'SEASONAL CONVERSIONS'
                       ELSE
                           NULL
                   END, --    cond1c,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND2')
                       WHEN 'Y'
                       THEN
                           'INTERCOUNTY PRIORITIES, NO SALE 5 YEARS'
                       ELSE
                           NULL
                   END, --    cond2,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND5')
                       WHEN 'Y'
                       THEN
                           'PRIORITIES 1995 AND LATER, NO SALE 2 YEARS'
                       ELSE
                           NULL
                   END, --    cond5,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND7')
                       WHEN 'Y'
                       THEN
                           'OPERATING RESTRICTIONS'
                       ELSE
                           NULL
                   END, --    cond7,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND8')
                       WHEN 'Y'
                       THEN
                           'CODE 8 - SELF-INCORPORATION - HISTORICAL VALUE'
                       ELSE
                           NULL
                   END, --    cond8,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'COND9')
                       WHEN 'Y'
                       THEN
                           'TIED HOUSE UNDERTAKINGS'
                       ELSE
                           NULL
                   END, --    cond9,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'CONDA')
                       WHEN 'Y'
                       THEN
                           '23824 CITY/COUNTY OWNED PROPERTY, PERS-PERS ONLY'
                       ELSE
                           NULL
                   END, --    conda,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'CONDD')
                       WHEN 'Y'
                       THEN
                           'PERS-PERS TRANSFER ONLY, PER SECTION 23817.5'
                       ELSE
                           NULL
                   END, --    condd,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'CONDG')
                       WHEN 'Y'
                       THEN
                           'SECTION 23433 - GOLF CLUB NON-TRANSFERABLE'
                       ELSE
                           NULL
                   END, --    condg,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'CONDI')
                       WHEN 'Y'
                       THEN
                           'INTERNET SALES ONLY'
                       ELSE
                           NULL
                   END, --    condi,
                   CASE api.pkg_columnquery.VALUE(t_licensetypejobid,
                                                  'CONDM')
                       WHEN 'Y'
                       THEN
                           'MICROENTERPRISE HOME KITCHEN'
                       ELSE
                           NULL
                   END --    condm
                      )
          INTO t_cond_desc
          FROM l;

        RETURN t_cond_desc;
    END;

    -- ****************************************************************************
    --  transfer Licenses
    -- ****************************************************************************
    FUNCTION transfer(a_licensetypejobid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        t_packet       CLOB;
    BEGIN
        WITH
            info
            AS
                (SELECT json_object(
                            'TO' VALUE tr.transtolicensenumber,
                            'TRANSFERDDON' VALUE
                                api.pkg_columnquery.datevalue(
                                    tr.transtoltjobid,
                                    'ISSUEDATE'))    data
                   FROM sitespecific.licensetransfers_t tr
                  WHERE tr.transfromltjobid = a_licensetypejobid
                    AND tr.objectid =
                        (SELECT MAX(t2.objectid)
                           FROM sitespecific.licensetransfers_t t2
                          WHERE t2.transfromltjobid = a_licensetypejobid)
                 UNION
                 SELECT json_object(
                            'FROM' VALUE tr.transfromlicensenumber,
                            'TRANSFEREDON' VALUE
                                api.pkg_columnquery.datevalue(
                                    tr.transtoltjobid,
                                    'ISSUEDATE'))
                   FROM sitespecific.licensetransfers_t tr
                  WHERE tr.transtoltjobid = a_licensetypejobid
                    AND tr.objectid =
                        (SELECT MAX(t2.objectid)
                           FROM sitespecific.licensetransfers_t t2
                          WHERE t2.transtoltjobid = a_licensetypejobid))
        SELECT json_arrayagg(data FORMAT JSON)
          INTO t_packet
          FROM info;

        RETURN t_packet;
    END;

    -- ****************************************************************************
    --  SECONDARY License Types
    -- ****************************************************************************
    FUNCTION secondary(a_licensetypejobid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        t_packet       CLOB;
        t_tbl          clob_tbl := clob_tbl();
        t_transfer     CLOB;
    BEGIN
        t_transfer := transfer(a_licensetypejobid);

          SELECT json_object(
                     'LICENSETYPECODE' VALUE
                         api.pkg_columnquery.VALUE(slt.toobjectid,
                                                   'LicenseTypeCode'),
                     'STATUS' VALUE
                         utl_licenseinfo.statusmatrix(
                             api.pkg_columnquery.VALUE(slt.relationshipid,
                                                       'Status')),
                     'STATUSDATE' VALUE
                         NVL(
                             api.pkg_columnquery.datevalue(slt.relationshipid,
                                                           'EFFECTIVEDATE'),
                             api.pkg_columnquery.datevalue(a_licensetypejobid,
                                                           'StatusDateCorral')), -- status date
                     'TERM' VALUE 12, -- term
                     'ISSUEDATE' VALUE
                         api.pkg_columnquery.datevalue(slt.relationshipid,
                                                       'IssueDate'), -- original issue date
                     'EXPIRATIONDATE' VALUE
                         api.pkg_columnquery.datevalue(slt.fromobjectid,
                                                       'ExpiratiONDate'),
                     'MASTERINDICATOR' VALUE 'N', --master indicator
                     'DUPLICATECOUNT' VALUE
                         api.pkg_columnquery.numericvalue(slt.relationshipid,
                                                          'LicenseTypeCount'), -- duplicate count
                     'FEECODE' VALUE
                         api.pkg_columnquery.VALUE(a_licensetypejobid,
                                                   'FeeScheduleCode'), -- fee code
                     'TRANSFER' VALUE t_transfer FORMAT JSON)
            BULK COLLECT INTO t_tbl
            FROM api.relationships slt
           WHERE (slt.fromobjectid = a_licensetypejobid
              AND slt.endpointid =
                  api.pkg_configquery.endpointidforname('j_LicenseType',
                                                        'LicTypeCatSecONdary'))
        ORDER BY api.pkg_columnquery.VALUE(slt.toobjectid, 'LicenseTypeCode');

        SELECT json_arrayagg(VALUE(e) FORMAT JSON)
          INTO t_packet
          FROM TABLE(t_tbl) e;

        RETURN t_packet;
    END;


    FUNCTION licensetypes(a_licensejobid IN api.pkg_definition.udt_id)
        RETURN CLOB
    IS
        t_packet       CLOB;
        t_tbl          clob_tbl := clob_tbl();
    BEGIN
        FOR job
            IN (SELECT r.toobjectid     id
                  FROM api.relationships r
                 WHERE r.endpointid =
                       api.pkg_configquery.endpointidforname('j_License',
                                                             'LicenseType')
                   AND r.fromobjectid = a_licensejobid)
        LOOP
            t_tbl.EXTEND(1);

            t_tbl(t_tbl.COUNT) :=
                json_object(
                    'LICENSETYPECODE' VALUE
                        api.pkg_columnquery.VALUE(job.id, 'LicenseTypeCode'),
                    'LICENSETYPECODEOBJECTID' VALUE job.id,
                    'STATUS' VALUE
                        utl_licenseinfo.statusmatrix(
                            api.pkg_columnquery.VALUE(job.id,
                                                      'StatusDescription')),
                    'STATUSDATE' VALUE
                        api.pkg_columnquery.datevalue(job.id,
                                                      'StatusDateCorral'), -- status date
                    'TERM' VALUE 12, -- term
                    'ISSUEDATE' VALUE
                        api.pkg_columnquery.datevalue(job.id, 'IssueDate'), -- original issue date
                    'EXPIRATIONDATE' VALUE
                        api.pkg_columnquery.datevalue(job.id,
                                                      'dup_ExpirationDate'),
                    'MASTERINDICATOR' VALUE 'Y', --master indicator
                    'DUPLICATECOUNT' VALUE 0, -- duplicate count
                    'FEECODE' VALUE -- fee code
                        api.pkg_columnquery.VALUE(job.id, 'FeeScheduleCode'),
                    'SECONDARY' VALUE secondary(job.id) FORMAT JSON,
                    'CONDIIONS' VALUE
                        conditions(a_licensejobid, job.id) FORMAT JSON,
                    'TRANSFER' VALUE transfer(job.id) FORMAT JSON);
        END LOOP;

        SELECT json_arrayagg(VALUE(e) FORMAT JSON)
          INTO t_packet
          FROM TABLE(t_tbl) e;

        RETURN t_packet;
    END;

    FUNCTION operatingrestrictions(a_objectid IN NUMBER)
        RETURN CLOB
    IS
        t_tbl          clob_tbl := clob_tbl();
        t_packet       CLOB;
    BEGIN
          SELECT CASE
                     WHEN info.copiesmailed <
                          TO_DATE('05/01/2017', 'MM/DD/YYYY')
                     THEN
                         '"*Operating Restrictions exist. For more information, please see our Guidelines for Access to Records."'
                     ELSE
                         '"' || info.operatingrestrictions || '"'
                 END    operatingrestrictions
            BULK COLLECT INTO t_tbl
            FROM (  SELECT --1              cnt,
                           api.pkg_columnquery.VALUE(lic_c.relationshipid,
                                                     'ConditionText')
                               operatingrestrictions,
                           api.pkg_columnquery.numericvalue(lic_c.relationshipid,
                                                            'sort')
                               sort,
                           NVL(
                               api.pkg_columnquery.datevalue(lic_a.toobjectid,
                                                             'copiesmailed'),
                               TO_DATE('05/01/2017', 'MM/DD/YYYY') - 1)
                               copiesmailed
                      FROM api.relationships lic_c
                           JOIN api.relationships lic_a
                               ON (lic_a.endpointid =
                                   api.pkg_configquery.endpointidforname(
                                       'j_License',
                                       'ApplicationLicense')
                               AND lic_a.fromobjectid = lic_c.fromobjectid)
                     WHERE lic_c.endpointid =
                           api.pkg_configquery.endpointidforname('j_license',
                                                                 'Condition')
                       AND lic_c.fromobjectid = a_objectid
                       AND api.pkg_columnquery.VALUE(lic_c.toobjectid,
                                                     'ISCONDITION') =
                           'Y'
                  ORDER BY sort) info
        ORDER BY sort;

        SELECT json_arrayagg(VALUE(e) FORMAT JSON)
          INTO t_packet
          FROM TABLE(t_tbl) e;

        RETURN t_packet;
    END;

    -- ***************************************
    --  DISCIPLINARYACTIONS:
    -- ***************************************
    FUNCTION disciplinaryactions(a_licensejobid IN NUMBER)
        RETURN CLOB
    IS
        t_packet       CLOB;
    BEGIN
        SELECT json_arrayagg(
                   api.pkg_columnquery.numericvalue(objectid, 'REGNUMBER'))
          INTO t_packet
          FROM (SELECT DISTINCT inv.toobjectid     objectid
                  FROM api.relationships  lic
                       JOIN api.relationships inv
                           ON inv.fromobjectid = lic.toobjectid
                          AND inv.endpointid = 297336 /* j_Investigation (Accusation) --> j_Accusation */
                 WHERE lic.endpointid = 328986 /*  j_License (Investigation) --> j_Investigation */
                   AND api.pkg_columnquery.VALUE(inv.toobjectid,
                                                 'STATUSNAME') NOT IN
                           ('CLOSED', 'DISMSD')
                   AND api.pkg_columnquery.VALUE(inv.toobjectid, 'REGNUMBER')
                           IS NOT NULL
                   AND lic.fromobjectid = a_licensejobid);


        RETURN t_packet;
    END;

    -- ***************************************
    --  DISCIPILINARYHISTORY:
    -- ***************************************
    FUNCTION discipilinaryhistory(a_licensejobid IN NUMBER)
        RETURN CLOB
    IS
        t_packet       CLOB;
    BEGIN
        SELECT json_arrayagg(
                   json_object(
                       'REGNUMBER' VALUE
                           api.pkg_columnquery.numericvalue(objectid,
                                                            'REGNUMBER'),
                       'PROCEEDINGSTATUS' VALUE
                           api.pkg_columnquery.VALUE(objectid, 'STATUSNAME')))
          INTO t_packet
          FROM (SELECT DISTINCT inv.toobjectid     objectid
                  FROM api.relationships  lic
                       JOIN api.relationships inv
                           ON inv.fromobjectid = lic.toobjectid
                          AND inv.endpointid = 297336 /* j_Investigation (Accusation) --> j_Accusation */
                 WHERE lic.endpointid = 328986 /*  j_License (Investigation) --> j_Investigation */
                   AND api.pkg_columnquery.VALUE(inv.toobjectid,
                                                 'STATUSNAME') IN
                           ('CLOSED', 'DISMSD')
                   AND api.pkg_columnquery.VALUE(inv.toobjectid, 'REGNUMBER')
                           IS NOT NULL
                   AND lic.fromobjectid = a_licensejobid);

        RETURN t_packet;
    END;

    -- ***************************************
    --  HOLDS
    -- ***************************************
    FUNCTION holds(a_licensejobid IN NUMBER)
        RETURN CLOB
    IS
        t_packet       CLOB;
    BEGIN
        SELECT json_arrayagg(
                   json_object(
                       'HOLDTYPE' VALUE
                           api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'HOLDTYPE'),
                       'HOLDCREATEDDATE' VALUE
                           api.pkg_columnquery.VALUE(r.toobjectid,
                                                     'HOLDCREATEDDATE')))
          INTO t_packet
          FROM api.relationships r
         WHERE r.fromobjectid = a_licensejobid
           AND r.endpointid = 311500 /* Hold */
           AND api.pkg_columnquery.VALUE(r.toobjectid, 'HOLDRELEASED')
                   IS NULL
           AND api.pkg_columnquery.VALUE(r.toobjectid, 'HOLDTYPE') NOT IN
                   ('PENDING DISCIPLINARY ACTION',
                    'DISTRICT SPECIAL HOLD',
                    'REACTIVATED PER THE EXECUTIVE STAFF');

        RETURN t_packet;
    END;
-- ****************************************************************************
-- ****************************************************************************
--  Main Function Body
-- ****************************************************************************
-- ****************************************************************************
BEGIN
    DECLARE
        t_packet       CLOB;
        t_objectid     api.pkg_definition.udt_id;
        l_obj          json_object_t;
        t_array        json_array_t := json_array_t();
    BEGIN
        FOR licenses
            IN (SELECT objectid
                  FROM JSON_TABLE(
                           a_packet,
                           '$[*]'
                           COLUMNS(
                               NESTED PATH '$.DATA.OBJECTIDS[*]'
                                   COLUMNS(objectid PATH '$'))))
        LOOP
            t_objectid := licenses.objectid;
            t_packet :=
                json_object(
                    'LICENSEOBJECTID' VALUE t_objectid,
                    'LICENSENUMBER' VALUE
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'licensenumber'),
                    'PRIMARYLICENSEE' VALUE
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'PrimaryLicensee'), -- Primary Owner
                    'BUSINESSNAME' VALUE
                        api.pkg_columnquery.VALUE(t_objectid, 'PrimaryDBA'), -- DBA
                    'BASEFILEOFFICE' VALUE
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'BaseFileOfficeName'), --base file office
                    'PREMISEADDRESS' VALUE
                        TRIM(
                            api.pkg_columnquery.VALUE(t_objectid,
                                                      'PremAddressLine1')
                            || ' '
                            || api.pkg_columnquery.VALUE(t_objectid,
                                                         'PremAddressLine2')), -- Business Address
                    'PREMISECITYSTYZIP' VALUE
                        CASE
                            WHEN api.pkg_columnquery.VALUE(
                                     t_objectid,
                                     'PremAddressUSCity')
                                     IS NULL
                            THEN
                                NULL
                            ELSE
                                api.pkg_columnquery.VALUE(
                                    t_objectid,
                                    'PremAddressUSCity') -- Business City
                                || ', '
                                || api.pkg_columnquery.VALUE(
                                       api.pkg_columnquery.VALUE(
                                           t_objectid,
                                           'PremisesAddressObjectId'),
                                       'USAStateCode')
                                || '. '
                                || api.pkg_columnquery.VALUE(
                                       t_objectid,
                                       'PremAddressZipCode')
                        END,
                    'CENSUSTRACK' VALUE
                        TO_CHAR(
                            api.pkg_columnquery.VALUE(
                                t_objectid,
                                'PremAddressCensusTract'),
                            'FM0000.00'), -- censustrack
                    'COUNTY' VALUE
                        api.pkg_columnquery.VALUE(t_objectid,
                                                  'PremAddressCounty'), -- county
                    'MAILINGADDRESS' VALUE
                        CASE
                            WHEN api.pkg_columnquery.VALUE(
                                     t_objectid,
                                     'MailingAddressLine1')
                                     IS NULL
                            THEN
                                NULL
                            ELSE
                                api.pkg_columnquery.VALUE(
                                    t_objectid,
                                    'MailingAddressLine1') -- mailing address
                                || ' '
                                || api.pkg_columnquery.VALUE(
                                       t_objectid,
                                       'MailingAddressLine2')
                        END, -- Business Address
                    'MAILINGCITYSTZIP' VALUE
                        CASE
                            WHEN api.pkg_columnquery.VALUE(
                                     t_objectid,
                                     'MailingAddressCity')
                                     IS NULL
                            THEN
                                NULL
                            ELSE
                                api.pkg_columnquery.VALUE(
                                    t_objectid,
                                    'MailingAddressCity')
                                || ', '
                                || api.pkg_columnquery.VALUE(
                                       api.pkg_columnquery.VALUE(
                                           t_objectid,
                                           'PremisesAddressObjectId'),
                                       'USAStateCode')
                                || '. '
                                || api.pkg_columnquery.VALUE(
                                       t_objectid,
                                       'MailingAddressZipCode')
                        END, -- mailing city st zip
                    -- ***************************************
                    --  LEGALENTITIES
                    -- ***************************************
                    'LEGALENTITY' VALUE getentityinfo(t_objectid) FORMAT JSON,
                    -- ***************************************
                    --  License Types plus Secondarys
                    -- ***************************************
                    'LICENSE_TYPES' VALUE
                        licensetypes(t_objectid) FORMAT JSON,
                    -- ***************************************
                    --  OPERATINGRESTRICTIONS:
                    -- ***************************************
                    'OPERATINGRESTRICTIONS' VALUE
                        operatingrestrictions(t_objectid) FORMAT JSON,
                    -- ***************************************
                    --  DISCIPLINARYACTIONS:
                    -- ***************************************
                    'DISCIPLINARYACTIONS' VALUE
                        disciplinaryactions(t_objectid) FORMAT JSON,
                    -- ***************************************
                    --  DISCIPILINARYHISTORY:
                    -- ***************************************
                    'DISCIPILINARYHISTORY' VALUE
                        discipilinaryhistory(t_objectid) FORMAT JSON,
                    -- ***************************************
                    --  HOLDS:
                    -- ***************************************
                    'HOLDS' VALUE holds(t_objectid) FORMAT JSON);

            t_array.append(json_element_t.parse(t_packet));
        END LOOP;

        l_obj :=
            NEW json_object_t(
                    json_object('PACKET_TYPE' VALUE 'LICENSEINFO',
                                'DATA' VALUE t_array.TO_CLOB FORMAT JSON));
        bizmod_api.utl_licenseinfo.clean(l_obj);

--        DBMS_OUTPUT.put_line(
--            json_query(l_obj.TO_CLOB, '$' RETURNING CLOB PRETTY));
        RETURN l_obj.TO_CLOB;
--        RETURN;
    END;
END;
/
