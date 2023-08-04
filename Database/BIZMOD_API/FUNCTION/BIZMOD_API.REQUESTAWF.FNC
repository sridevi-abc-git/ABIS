CREATE OR REPLACE FUNCTION BIZMOD_API.requestawf(a_packet IN CLOB, a_seq IN NUMBER)
    RETURN CLOB
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.REQUESTAWF.FNC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :    This function is called thru the eservices API to return
    --              ABC-261 license information. A JSON packet license number
    --              is passed into this function to retrieve the information
    --              required by LSP. The license lnformation will be returned
    --              in a JSON packet.
    --
    -- History:
    -------------------------------------------------------------------------------
    --  Ver:       Date          Ticket       Comment
    --          06/08/2022 TJL  BIZ-        Initial Function Created
    --          02/16/2023 TJL              Converted to using JSON objects.
    --          06/28/2023 TJL              Fixed bug in generating return packet
    --          07/06/2023 TJL  BIZ-11891   Change which renewal fee being returned
    --         07/19/2023 TJL  BIZ-11977 Fixed bug where liccenses without application
    --                  would throw exception License Not Found.
    --          07/20/2023 TJL  BIZ-11991   Change what date is used in figuring out which
    --                                         renewal is returned
    --   2.1    07/25/2023 TJL  BIZ-12090   Added FeeRequired and Justification fields to return packet
    --   2.2    07/27/2023 TJL  BIZ-12070   Added error handling for renewal fee not found
    -- ****************************************************************************

    -- ****************************************************************************
    --
    -- ****************************************************************************
    t_objectid     api.pkg_definition.udt_id;
    t_licensenumber VARCHAR(10);
    t_expiration   DATE;
    t_fiscal_end   DATE
        := TO_DATE('30-06-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, 6)),
                   'dd-mm-yyyy');
    t_msgno        NUMBER;
    t_renfeeid     NUMBER;
    t_feeobjid     NUMBER;
    t_awfdate      DATE;
    t_renfeeactivity VARCHAR2(20);
    t_awf          VARCHAR2(4000);
    t_paidamount   NUMBER;
    l_data         json_object_t;
    l_obj          json_object_t;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    -- get license number from request packet
    SELECT json_value(a_packet, '$.*.LICENSENUMBER')
      INTO t_licensenumber
      FROM DUAL;

    WITH
        licensetypes
        AS
            (SELECT o.objectid,
                    api.pkg_columnquery.VALUE(o.objectid, 'LicenseTypeCode')    licensetypecode
               FROM TABLE(
                        CAST(
                            api.pkg_simplesearch.castableobjectsbyindex(
                                a_objectdefname => 'j_LicenseType',
                                a_columnname => 'dup_LicenseExternalFileNum',
                                a_value     => t_licensenumber)
                                AS api.udt_objectlist)) o)
    SELECT objectid
      INTO t_objectid
      FROM licensetypes lt
     WHERE lt.licensetypecode IN ('02', '22');

    t_msgno := bizmod_api.utl_licenseinfo.awfrequired(t_objectid);

    IF (t_msgno IS NULL)
    THEN
        t_expiration :=
            api.pkg_columnquery.datevalue(t_objectid, 'ExpirationDate');

        t_feeobjid :=
            bizmod_api.utl_licenseinfo.get_awfreninfo(
                a_fiscalend => t_fiscal_end,
                a_jobid     => t_objectid);

        if (t_feeobjid is not null) then
        t_renfeeid := api.pkg_columnquery.numericvalue(t_feeobjid, 'FeeId');
        t_awfdate :=
            api.pkg_columnquery.datevalue(t_feeobjid, 'TransactionDate');
        t_renfeeactivity :=
            REGEXP_SUBSTR(
                api.pkg_columnquery.VALUE(t_feeobjid,
                                          'FeeScheduleDescription'),
                '[^ ]+',
                1,
                3);
        t_paidamount :=
              api.pkg_columnquery.numericvalue(t_feeobjid, 'adjustedamount')
            + api.pkg_columnquery.numericvalue(t_feeobjid, 'paidamount');


        MERGE INTO bizmod_api.awf_t a
             USING (SELECT t_renfeeid renfeeid FROM DUAL) a2
                ON (a.renfeeid = a2.renfeeid)
        WHEN NOT MATCHED
        THEN
            INSERT     (renfeeid,
                        renfeeobjid,
                        licensenumber,
                        licensetypejobid,
                        licensetypecode,
                        expirationdate,
                        awfdate,
                        renactivity,
                        currgallonage,
                        curraddionalgallonage,
                        renewalamountpaid)
                VALUES (
                    t_renfeeid,
                    t_feeobjid,
                    t_licensenumber,
                    t_objectid,
                    api.pkg_columnquery.VALUE(t_objectid, 'LicenseTypeCode'),
                    t_expiration,
                    t_awfdate,
                    t_renfeeactivity,
                    api.pkg_columnquery.VALUE(t_objectid, 'GallonageRange'),
                    api.pkg_columnquery.numericvalue(
                        t_objectid,
                        'AdditionalMillionGallons'),
                    t_paidamount);

        COMMIT;
        else
            t_msgno := 14;
        END IF;
    END IF;

    l_obj :=
        NEW json_object_t(
                json_object(
                    'PACKET_TYPE' VALUE 'LICENSEAWFINFO',
                    'DATA' VALUE
                        json_object(
                            --                            'LICENSEOBJECTID' VALUE t_objectid,
                            'LICENSENUMBER' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'licensenumber'),
                            'LICENSEENAME' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'PrimaryLicensee'), -- PRIMARY OWNER
                            'BUSINESSNAME' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'PrimaryDBA'), -- DBA
                            'PREMISEADDRESS' VALUE
                                TRIM(
                                    api.pkg_columnquery.VALUE(
                                        t_objectid,
                                        'PremAddress1stOf2Lines')), -- business address
                            'PREMISECITYSTYZIP' VALUE
                                api.pkg_columnquery.VALUE(
                                    t_objectid,
                                    'PremAddress2ndOf2Lines'))));

    l_data := l_obj.get_object('DATA');

    IF (t_msgno IS NOT NULL)
    THEN
        l_data.put('MSGNO', t_msgno);
        l_data.put(
            'MSG',
            CASE t_msgno
                WHEN 7 THEN 'License has not been renewed for this year.'
                WHEN 8 THEN 'License is a Branch License.'
                WHEN 9 THEN 'AWF Fee already paid for this renewal year.'
                WHEN 10 THEN 'License was issued this licensing period.'
                WHEN 14 THEN 'Renewal/Annual Fee Not found for license number.'
                WHEN 0 THEN 'Application Annual Fee Not Found'
                ELSE 'Unknown error'
            END);
    ELSE
        SELECT json_object(
                   'FEEID' VALUE t.renfeeid,
                   'LICENSETYPECODE' VALUE t.licensetypecode,
                   'DESCRIPTION' VALUE t.description,
                   'FEEACTIVITY' VALUE t.renactivity,
                   'EXPIRATIONDATE' VALUE t.expirationdate,
                   'AWFDATE' VALUE t.awfdate,
                   'RENEWALAMOUNT' VALUE t.renewalamountpaid,
                   'CURRENTGALLONAGE' VALUE t.currgallonage,
                   'ADDITIONALGALLONAGE' VALUE t.curraddionalgallonage,
                   'CREATEDDATE' VALUE t.createddate,
                   'GALLONAGE' VALUE t.gallonage261,
                   'AWFAMOUNTOWED' VALUE t.awffeeamount,
                   'JUSTIFICATION' VALUE t.justification,
                   'FEEREQUIRED' VALUE t.feerequired,
                   'AWFPAID' VALUE NULL
                   ABSENT ON NULL)
          INTO t_awf
          FROM bizmod_api.awf_t t
         WHERE t.renfeeid = t_renfeeid;

        l_data.put('INFO',
                   TREAT(json_object_t.parse(t_awf) AS json_object_t));
    END IF;

    RETURN l_obj.TO_CLOB;
EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);
        DBMS_OUTPUT.put_line(t_msg);

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE 1,
                           'MSG' VALUE
                               'License Number '
                               || t_licensenumber
                               || ' Not Found'));
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || ' :: ' || t_trace, 1, 3990);

        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;

        RETURN json_object(
                   'PACKET_TYPE' VALUE 'MESSAGE',
                   'DATA' VALUE
                       json_object(
                           'MSGNO' VALUE 5,
                           'MSG' VALUE
                               'Oracle Exception","EXCEPTION":"(Seq: '
                               || a_seq
                               || ') '
                               || t_msg));
END;
/
