CREATE OR REPLACE FUNCTION BIZMOD_API.requestawf(a_packet       IN CLOB,
                                                 a_seq          IN NUMBER)
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
    --   3.0    08/08/2023 TJL  BIZ-12019   Added checking for 02 and 22 active on same license number
    --   3.0    08/09/2023 TJL  BIZ-12298   Changed how paid amount is calculated
    --   3.0    08/09/2023 TJL  BIZ-11857   Change code to return licensee names instead of primary licensee
    --   3.0    09/10/2023 TJL  BIZ-12315   Corrected bug in getting paid amount when ren50 and ren100
    --   4.0    03/26/2024 TJL  BIZ-14833   Change where and how information is retrieve for AWF Report
    --   4.1    03/29/2024 TJL  BIZ-14833   Fix bug of not getting renew fee activity
    --   5.0    08/07/2024 TJL  BIZ-15995   Made checking for payments using license expiration date.
    --   6.0    08/26/2024 TJL  BIZ-16121   Change what date is used to call checkpayment function  
    -- ****************************************************************************

    -- ****************************************************************************
    --
    -- ****************************************************************************
    t_objectid     api.pkg_definition.udt_id;
    t_licensenumber VARCHAR2(10);
    t_licensetypecode VARCHAR2(3);
    t_expiration   DATE;
    t_fiscal_start DATE
        := TO_DATE('01-07-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, -6)),
                   'dd-mm-yyyy');
    t_fiscal_end   DATE
        := TO_DATE('30-06-' || EXTRACT(YEAR FROM ADD_MONTHS(SYSDATE, 6)),
                   'dd-mm-yyyy');
    t_msgno        NUMBER := 16;
    t_renfeeid     NUMBER;
    t_feeobjid     NUMBER;
    t_awfdate      DATE;
    t_renfeeactivity VARCHAR2(20);
    t_paidamount   NUMBER;
    l_data         json_object_t;
    l_obj          json_object_t;
    t_lst          api.udt_objectlist := api.udt_objectlist();
    t_arr          json_array_t;
    t_awf          CLOB;
    t_active       NUMBER := 0;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
BEGIN
    FOR rec
        IN (SELECT lt.licensenumber,
                   lt.licensetypejobid
                       licensetypeobjectid,
                   lt.licensetypecode,
                   lt.licensetypeexpirationdate
                       expirationdate,
                   lt.awfflag
                       awf,
                   CASE lt.awfflag
                       WHEN 'Y'
                       THEN
                           bizmod_api.utl_licenseinfo.checkpayment(
                               a_licensenumber => lt.licensenumber,
                               a_licensetypecode => lt.licensetypecode,
                               --08/26/2024 TJL  BIZ-16121
                               a_renewalfeedate => t_fiscal_start)
                       ELSE
                           lt.awfflag
                   END
                       awfflag,
                   lt.renfeeobjid
                       feeobjid,
                   api.pkg_columnquery.numericvalue(lt.renfeeobjid,
                                                    'FeeId')
                       renfeeid,
                   api.pkg_columnquery.datevalue(lt.renfeeobjid,
                                                 'TransactionDate')
                       awfdate,
                   REGEXP_SUBSTR(
                       api.pkg_columnquery.VALUE(lt.renfeeobjid,
                                                 'FeeScheduleDescription'),
                       '[^ ]+',
                       1,
                       3)
                       renfeeactivity,
                   CASE
                       WHEN REGEXP_SUBSTR(
                                api.pkg_columnquery.VALUE(
                                    lt.renfeeobjid,
                                    'FeeScheduleDescription'),
                                '[^ ]+',
                                1,
                                3) IN
                                ('REN50', 'REN100')
                       THEN
                           -(api.pkg_columnquery.numericvalue(lt.renfeeobjid,
                                                              'Amount'))
                       ELSE
                             api.pkg_columnquery.numericvalue(
                                 lt.renfeeobjid,
                                 'adjustedamount')
                           + api.pkg_columnquery.numericvalue(lt.renfeeobjid,
                                                              'paidamount')
                   END
                       paidamount
              FROM JSON_TABLE(
                       a_packet,
                       '$'
                       COLUMNS(
                           packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                           NESTED PATH '$.DATA[*]'
                               COLUMNS(
                                   licensenumber VARCHAR2(1000)
                                       PATH '$.LICENSENUMBER',
                                   licensetypecode VARCHAR2(3)
                                       PATH '$.LICENSETYPECODE'))) jlt
                   JOIN bizmod_api.licensetype_t lt
                       ON (lt.licensenumber = jlt.licensenumber
                       AND lt.licensetypecode =
                           NVL(jlt.licensetypecode, lt.licensetypecode)
                       AND lt.licensetypecode IN ('02', '22')))
    LOOP
        IF (rec.awfflag = 'Y')
        THEN
            t_lst.EXTEND(1);
            t_lst(t_lst.COUNT) := api.udt_object(rec.renfeeid);
            t_msgno := NULL;

            t_objectid := rec.licensetypeobjectid;
            t_renfeeid := rec.renfeeid;

            MERGE INTO bizmod_api.awf_t a
                 USING (SELECT t_renfeeid renfeeid FROM DUAL) a2
                    ON (a.renfeeid = a2.renfeeid)
            WHEN MATCHED
            THEN
                UPDATE SET
                    expirationdate = rec.expirationdate,
                    awfdate = rec.awfdate,
                    renactivity = rec.renfeeactivity,
                    currgallonage =
                        CASE api.pkg_columnquery.VALUE(rec.feeobjid,
                                                       'FeeCode')
                            WHEN 'GL5K'
                            THEN
                                '0 TO 5K'
                            WHEN 'GL20K'
                            THEN
                                '5K TO 20K'
                            WHEN 'GL100K'
                            THEN
                                '20K TO 100K'
                            WHEN 'GL200K'
                            THEN
                                '100K TO 200K'
                            ELSE
                                '200K TO 1M'
                        END,
                    curraddionalgallonage =
                        api.pkg_columnquery.numericvalue(rec.feeobjid,
                                                         'SecondaryCount'),
                    renewalamountpaid = rec.paidamount
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
                        rec.renfeeid,
                        rec.feeobjid,
                        rec.licensenumber,
                        rec.licensetypeobjectid,
                        rec.licensetypecode,
                        rec.expirationdate,
                        rec.awfdate,
                        rec.renfeeactivity,
                        CASE api.pkg_columnquery.VALUE(rec.feeobjid,
                                                       'FeeCode')
                            WHEN 'GL5K'
                            THEN
                                '0 TO 5K'
                            WHEN 'GL20K'
                            THEN
                                '5K TO 20K'
                            WHEN 'GL100K'
                            THEN
                                '20K TO 100K'
                            WHEN 'GL200K'
                            THEN
                                '100K TO 200K'
                            ELSE
                                '200K TO 1M'
                        END,
                        api.pkg_columnquery.numericvalue(rec.feeobjid,
                                                         'SecondaryCount'),
                        rec.paidamount);

            COMMIT;
        ELSE
            IF (t_lst.COUNT = 0)
            THEN
                t_msgno :=
                    CASE rec.awfflag
                        WHEN 'NA' THEN 8
                        WHEN 'N' THEN 9
                        ELSE -1
                    END;
            END IF;
        END IF;
    END LOOP;

    l_obj :=
        NEW json_object_t(
                json_object(
                    'PACKET_TYPE' VALUE 'LICENSEAWFINFO',
                    'DATA' VALUE
                        json_object(
                            'LICENSEOBJECTID' VALUE t_objectid,
                            'LICENSENUMBER' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'licensenumber'),
                            'LICENSEENAME' VALUE
                                api.pkg_columnquery.VALUE(t_objectid,
                                                          'LicenseeNames'),
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
                WHEN 8
                THEN
                    'License is a Branch License.'
                WHEN 9
                THEN
                    'AWF Fee already paid for this renewal year.'
                WHEN 16
                THEN
                    'Renewal/Annual Fee Not found for license number.'
                --                WHEN 15
                --                THEN
                --                    'Two active license types (02,22) found for license'
                ELSE
                    'Unknown error'
            END);
    ELSE
        SELECT json_arrayagg(
                   json_object(
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
                   RETURNING CLOB)
          INTO t_awf
          FROM bizmod_api.awf_t  t
               JOIN TABLE(t_lst) l ON t.renfeeid = l.objectid;

        t_arr := NEW json_array_t(t_awf);
        l_data.put('INFO',
                   CASE t_lst.COUNT WHEN 1 THEN t_arr.get(0) ELSE t_arr END);
    END IF;

    bizmod_api.utl_licenseinfo.clean(l_obj);
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
