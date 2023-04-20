CREATE OR REPLACE PACKAGE BODY ABC.pkg_covid19
AS
    -- **************************************************************************
    -- File:        PKG_COVID19.PKB
    -- Author:      Timothy J.Lord
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 02/03/2021 TJL      - Package Created
    -- 07/01/2021 TJL 25546  Removed code for Fee Waiver Check Box 
    -- 05/04/2022 PK       - Added column Renewaldate to renewalinfotable to take care of Issue regarding renewal expiration dates that end on the weekend
    -- 05/20/2022 PK 28330 - Fee Waiver Relief for Wine Growers Dup 02
    -- 06/08/2022 NW       - Stop the bleeding. Added ISSUEDATE field to ABCLQS.RENEWAL_INFO
    -- **************************************************************************

---------------------------------------------------------------------
    PROCEDURE upd_cert(a_start_date IN DATE DEFAULT NULL, a_end_date IN DATE DEFAULT TRUNC(SYSDATE))
---------------------------------------------------------------------
    IS
        t_start_date   DATE := a_start_date;
        t_end_date     DATE := NVL(a_end_date, TRUNC(SYSDATE));
        t_batchseq     NUMBER;
        t_seq          NUMBER;
    BEGIN
        SELECT CASE
                   WHEN a_start_date IS NULL THEN TRUNC(NVL(MAX(rl.runtime - 1), TO_DATE('01-JAN-21')))
                   ELSE a_start_date
               END,
               NVL(MAX(rl.batchseq), 0) + 1
          INTO t_start_date, t_batchseq
          FROM abclqs.renewal_run_log rl;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype,
                                              rl.startdate,
                                              rl.enddate,
                                              rl.batchseq)
             VALUES ('upd_cert',
                     t_start_date,
                     t_end_date,
                     t_batchseq)
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;

        DBMS_OUTPUT.put_line(   'Start Date: '
                             || t_start_date
                             || '  End Date: '
                             || t_end_date);

        abc.pkg_covid19.upd_cert_renewal(a_start_date => t_start_date,
                                         a_end_date  => t_end_date,
                                         a_batchseq  => t_batchseq);

        
        -- 6/8/2022 NW added issuedate field to ABCLQS.RENEWAL_INFO to stop the bleeding 
        -- This is the simplest, less intrusive, easiest methode for now
        -- The upd_cert_renewal will/should be modified in the FOR LOOP when we get the chance.  
        UPDATE ABCLQS.RENEWAL_INFO RI 
        SET ISSUEDATE = (
          SELECT ISSUEDATE 
          FROM QUERY.J_LICENSETYPE LT 
          WHERE LT.OBJECTID	= RI.JOBID
        )
        WHERE ISSUEDATE IS NULL;
        COMMIT;
                          
        abc.pkg_covid19.upd_cert_penalty(a_penalty   => '50% PENALTY',
                                         a_start_date => t_start_date,
                                         a_end_date  => t_end_date,
                                         a_batchseq  => t_batchseq);
        abc.pkg_covid19.upd_cert_penalty(a_penalty   => '100% PENALTY',
                                         a_start_date => t_start_date,
                                         a_end_date  => t_end_date,
                                         a_batchseq  => t_batchseq);
        abc.pkg_covid19.upd_cert_payment(a_batchseq => t_batchseq);
        abc.pkg_covid19.upd_cert_license_issued(a_batchseq => t_batchseq);

        UPDATE abclqs.renewal_run_log rl
           SET rl.results   = 'Completed'
         WHERE rl.seq = t_seq;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype,
                                              rl.startdate,
                                              rl.enddate,
                                              rl.batchseq,
                                              rl.results)
             VALUES ('Job Completed',
                     t_start_date,
                     t_end_date,
                     t_batchseq,
                     'Job Completed')
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;
    END;

---------------------------------------------------------------------
    PROCEDURE upd_cert_renewal(a_start_date IN DATE, a_end_date IN DATE, a_batchseq IN NUMBER DEFAULT NULL)
---------------------------------------------------------------------
    IS
        t_msg                  VARCHAR2(4000 BYTE);
        t_skip                 BOOLEAN := FALSE;
        t_comma                BOOLEAN := FALSE;
        t_packet               CLOB := EMPTY_CLOB();
        t_fees                 CLOB := EMPTY_CLOB();
        t_totalamountdue       NUMBER := 0;
        t_count                NUMBER := 0;

        t_relieflicensetypes   VARCHAR2(400) := api.pkg_constantquery.VALUE('COVID19RELIEFLICENSETYPES');

        t_sqlerrm              VARCHAR2(4000);
        t_backtrace            VARCHAR2(4000);
        t_sqlcode              NUMBER;
        t_startincludedate     DATE := TO_DATE('01-MAR-20');
        t_begindate            DATE := TO_DATE('01-MAR-21');
        t_seq                  NUMBER;
        t_batchseq             NUMBER;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        CASE
            WHEN a_batchseq IS NOT NULL THEN
                t_batchseq   := a_batchseq;
            ELSE
                SELECT MAX(batchseq) + 1
                  INTO t_batchseq
                  FROM abclqs.renewal_run_log;
        END CASE;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype,
                                              rl.startdate,
                                              rl.enddate,
                                              rl.batchseq)
             VALUES ('upd_cert_renewal',
                     a_start_date,
                     a_end_date,
                     t_batchseq)
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;

        DBMS_OUTPUT.put_line('start upd_cert_renewal: ');

        FOR lic
            IN (SELECT licensetypeobjectid
                  FROM (WITH
                            batches
                            AS
                                (SELECT  /*+ materialize */
                                        *
                                   FROM (SELECT j.jobid,
                                                api.pkg_columnquery.VALUE(j.jobid, 'BatchType')
                                                    batchtype,
                                                api.pkg_columnquery.datevalue(j.jobid, 'ExpirationDate')
                                                    expirationdate
                                           FROM api.jobs j
                                          WHERE TRUNC(j.completeddate) BETWEEN a_start_date AND a_end_date) b
                                  WHERE NVL(b.batchtype, 'x') = '1ST RENEWAL NOTICES'
                                    AND b.expirationdate >= t_begindate)
                        SELECT DISTINCT x.licensetypejobid licensetypeobjectid
                          FROM batches b
                               JOIN sitespecific.licbatchlictype_xref_t x
                               ON x.licensebatchjobid = b.jobid  --                        ORDER BY LPAD(licensenumber, 7, ' ')
                                                               ))
        LOOP
            BEGIN
                -- get fees by license
                FOR rec
                    IN (SELECT ROWNUM
                                   line,
                               d.*,
                               ltc.licensetypename
                                   licensetypedescription,
                               CASE
                                   WHEN INSTR(t_relieflicensetypes, d.licensetypecode) > 0
                                    AND ((d.status = 'SURRENDERED'
                                      AND d.statusdate >= t_startincludedate)
                                      OR (d.status != 'SURRENDERED')) THEN
                                       'Y'
                                   ELSE
                                       'N'
                               END
                                   waiver,
                               CASE
                                   WHEN ltc.populationapplies = 'Y' THEN 'P'
                                   WHEN ltc.gallonageapplies = 'Y' THEN 'G'
                                   ELSE NULL
                               END
                                   rangetype,
                               CASE
                                   WHEN ltc.populationapplies = 'Y' THEN
                                       api.pkg_columnquery.VALUE(lic.licensetypeobjectid, 'PremisesPopulationRange')
                                   WHEN ltc.gallonageapplies = 'Y' THEN
                                       api.pkg_columnquery.VALUE(lic.licensetypeobjectid, 'GallonageRange')
                                   ELSE
                                       NULL
                               END
                                   rangevalue
                          FROM (SELECT 'S'
                                           primarysecondary,
                                       reo.objectid
                                           feeobjid,
                                       api.pkg_columnquery.numericvalue(reo.objectid, 'SecondaryCount')
                                           secondarycount,
                                       api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing')
                                           totalowing,
                                       f.amount,
                                       f.adjustedamount,
                                       f.amount + f.adjustedamount
                                           feeamount,
                                       f.paidamount,
                                       SUBSTR(f.description, 1, 2)
                                           licensetypecode,
                                       sltc.status,
                                       sltc.statusdate
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                       JOIN query.r_licensetypeltcatsecondary sltc
                                       ON (sltc.licensetypejobid = f.jobid)
                                       JOIN query.o_licensetypecategory ltc
                                       ON (sltc.licensetypecategoryobjectid = ltc.objectid
                                       AND ltc.licensetypecode = fs.licensetypecode)
                                       -- check if secondary license type is same as primary
                                       JOIN api.relationships r
                                       ON (r.endpointid =
                                           api.pkg_configquery.endpointidforname('j_LicenseType',
                                                                                 'LicTypeCatPrimary')
                                       AND r.fromobjectid = f.jobid
                                       AND fs.licensetypecode !=
                                           api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode'))
                                 WHERE f.jobid = lic.licensetypeobjectid
                                   AND sltc.status IN ('ACTIVE',
                                                       'SURRENDERED',
                                                       'RULE 64B',
                                                       'SLMS HOLD',
                                                       'SUSPENDED')
                                   AND 'REN' LIKE
                                              '%'
                                           || SUBSTR(fs.feeactivity, 1, 3)
                                           || '%'
                                   AND (TRUNC(f.transactiondate), fs.licensetypecode) =
                                       (  SELECT TRUNC(MAX(f2.transactiondate)), fs2.licensetypecode
                                            FROM api.fees f2
                                                 JOIN api.registeredexternalobjects reo
                                                 ON reo.linkvalue = TO_CHAR(f2.feeid)
                                                AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')
                                                 JOIN sitespecific.feeschedule_t fs2
                                                 ON fs2.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                           WHERE f.jobid = f2.jobid
                                             AND fs.licensetypecode = fs2.licensetypecode
                                             AND fs2.feeactivity = fs.feeactivity
                                        GROUP BY fs2.licensetypecode)
                                UNION
                                SELECT CASE WHEN api.pkg_columnquery.VALUE(reo.objectid, 'IsMaster')= 'Y' THEN 'P' ELSE 'B' END   primarysecondary,  -- (Branch Primary License Type: Primary License Type) --05/18/2022  PK 28330 - Fee Waiver Relief for Wine Growers Dup 02),  -- (Branch Primary License Type: Primary License Type)
                                       reo.objectid                                                   feeobjid,
                                       0                                                              secondarycount,
                                       api.pkg_columnquery.numericvalue(reo.objectid, 'TotalOwing')   totalowing,
                                       f.amount,
                                       f.adjustedamount,
                                       f.amount + f.adjustedamount                                    feeamount,
                                       f.paidamount,
                                       SUBSTR(f.description, 1, 2)                                    licensetypecode,
                                       UPPER(api.pkg_columnquery.VALUE(f.jobid, 'StatusDescription')) status,
                                       api.pkg_columnquery.datevalue(f.jobid, 'StatusDate')           statusdate
                                  FROM api.fees f
                                       JOIN api.registeredexternalobjects reo
                                       ON reo.linkvalue = TO_CHAR(f.feeid)
                                      AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')
                                       JOIN sitespecific.feeschedule_t fs
                                       ON fs.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                       JOIN api.relationships r
                                       ON (r.endpointid =
                                           api.pkg_configquery.endpointidforname('j_LicenseType',
                                                                                 'LicTypeCatPrimary')
                                       AND r.fromobjectid = f.jobid
                                       AND fs.licensetypecode =
                                           api.pkg_columnquery.VALUE(r.toobjectid, 'LicenseTypeCode'))
                                 WHERE f.jobid = lic.licensetypeobjectid
                                   AND 'REN' LIKE
                                              '%'
                                           || SUBSTR(fs.feeactivity, 1, 3)
                                           || '%'
                                   AND (TRUNC(f.transactiondate), fs.licensetypecode) =
                                       (  SELECT TRUNC(MAX(f2.transactiondate)), fs2.licensetypecode
                                            FROM api.fees f2
                                                 JOIN api.registeredexternalobjects reo
                                                 ON reo.linkvalue = TO_CHAR(f2.feeid)
                                                AND reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Fee')
                                                 JOIN sitespecific.feeschedule_t fs2
                                                 ON fs2.objectid = sitespecific.pkg_fees.getlicfeeschedulobjid(f.feeid)
                                           WHERE f.jobid = f2.jobid
                                             AND fs.licensetypecode = fs2.licensetypecode
                                             AND fs2.feeactivity = fs.feeactivity
                                        GROUP BY fs2.licensetypecode)) d
                               JOIN query.o_licensetypecategory ltc
                               ON d.licensetypecode = ltc.licensetypecode)
                LOOP
                    -- insert record in renewal information table
                    INSERT  /*+ IGNORE_ROW_ON_DUPKEY_INDEX(renewal_info, renewal_info_pk) */
                           INTO abclqs.renewal_info(licensenumber,
                                                    jobid,
                                                    expirationdate,
                                                    renewaldate,
                                                    licensetypecode,
                                                    licensetypedescription,
                                                    rangetype,
                                                    rangevalue,
                                                    feeobjid,
                                                    secondarycount,
                                                    primarysecondary,
                                                    feeamount,
                                                    totalowing,
                                                    status,
                                                    statusdate)
                         VALUES (api.pkg_columnquery.VALUE(lic.licensetypeobjectid, 'LicenseNumber'),
                                 lic.licensetypeobjectid,
                                 api.pkg_columnquery.datevalue(lic.licensetypeobjectid, 'ExpirationDate'),
                                 api.pkg_columnquery.datevalue(lic.licensetypeobjectid, 'RenewalDate'), --Added column Renewaldate to renewalinfotable PK
                                 rec.licensetypecode,
                                 rec.licensetypedescription,
                                 rec.rangetype,
                                 rec.rangevalue,
                                 rec.feeobjid,
                                 rec.secondarycount,
                                 rec.primarysecondary,
                                 rec.feeamount,
                                 rec.totalowing,
                                 UPPER(rec.status),
                                 rec.statusdate)
                            LOG ERRORS INTO abclqs.err$_renewal_info
                                    ('INSERT')
                                    REJECT LIMIT UNLIMITED;

                    t_count   := t_count + SQL%ROWCOUNT;
                    COMMIT;
                END LOOP;
            EXCEPTION
                WHEN OTHERS THEN
                    t_sqlcode     := SQLCODE;
                    t_sqlerrm     := SQLERRM;
                    t_backtrace   := DBMS_UTILITY.format_error_backtrace;

                    api.pkg_logicaltransactionupdate.resettransaction;
                    ROLLBACK;

                    INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$,
                                                           e.ora_err_mesg$,
                                                           e.ora_err_tag$,
                                                           e.licensenumber,
                                                           e.jobid,
                                                           e.backtrace)
                         VALUES (t_sqlcode,
                                 SUBSTR(t_sqlerrm, 1, 2000),
                                 'EXCEPTION',
                                 api.pkg_columnquery.VALUE(lic.licensetypeobjectid, 'LicenseNumber'),
                                 lic.licensetypeobjectid,
                                 SUBSTR(t_backtrace, 1, 4000));

                    COMMIT;
            END;
        END LOOP;

        COMMIT;

        UPDATE abclqs.renewal_run_log rl
           SET rl.results     =
                      'Records Processed: '
                   || t_count,
               rl.SQLERRM     = t_sqlerrm,
               rl.backtrace   = t_backtrace
         WHERE rl.seq = t_seq;

        COMMIT;
        DBMS_OUTPUT.put_line(   'Records Added: '
                             || t_count);
    EXCEPTION
        WHEN OTHERS THEN
            t_sqlcode     := SQLCODE;
            t_sqlerrm     := SQLERRM;
            t_backtrace   := DBMS_UTILITY.format_error_backtrace;

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$, e.ora_err_mesg$, e.backtrace)
                 VALUES (t_sqlcode, SUBSTR(t_sqlerrm, 1, 2000), SUBSTR(t_backtrace, 1, 4000));

            COMMIT;
    END;

---------------------------------------------------------------------
    PROCEDURE upd_cert_payment(a_batchseq IN NUMBER DEFAULT NULL)
---------------------------------------------------------------------
    IS
        t_amountdue         NUMBER;
        t_eligible          VARCHAR2(20);
        t_licensetypecode   NUMBER;
        t_count1            NUMBER := 0;

        t_sqlerrm           VARCHAR2(4000);
        t_backtrace         VARCHAR2(4000);
        t_sqlcode           NUMBER;
        t_seq               NUMBER;
        t_batchseq          NUMBER;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        CASE
            WHEN a_batchseq IS NOT NULL THEN
                t_batchseq   := a_batchseq;
            ELSE
                SELECT MAX(batchseq) + 1
                  INTO t_batchseq
                  FROM abclqs.renewal_run_log;
        END CASE;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype,
                                              rl.startdate,
                                              rl.enddate,
                                              rl.batchseq)
             VALUES ('upd_cert_payment',
                     NULL,
                     NULL,
                     t_batchseq)
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;

        DBMS_OUTPUT.put_line('start upd_cert_payment: ');

        FOR rec
            IN (WITH
                    f
                    AS
                        (SELECT DISTINCT feeobjid, api.pkg_columnquery.numericvalue(feeobjid, 'FeeId') feeid
                           FROM (SELECT  /*+ materialize */
                                        ri.feeobjid,
                                        api.pkg_columnquery.numericvalue(ri.feeobjid, 'TotalOwing') totalowing
                                   FROM abclqs.renewal_info ri
                                  WHERE paymentbatch IS NULL)
                          WHERE totalowing <= 0)
                  SELECT feeobjid,
                         feeid,
                         LISTAGG(paymentobjectid, ',') WITHIN GROUP (ORDER BY paymentobjectid) paymentobjectid,
                         api.pkg_columnquery.numericvalue(feeobjid, 'jobid')                 jobid
                    FROM (SELECT DISTINCT feeobjid, f.feeid, reo.objectid paymentobjectid
                            FROM api.feetransactions ft
                                 JOIN api.paymenttransactions pt
                                 ON pt.transactionid = ft.transactionid
                                 JOIN api.registeredexternalobjects reo
                                 ON (reo.objectdefid = api.pkg_configquery.objectdefidforname('o_Payment')
                                 AND reo.linkvalue = TO_CHAR(pt.paymentid))
                                 JOIN f
                                 ON f.feeid = ft.feeid)
                GROUP BY feeobjid, feeid)
        LOOP
            BEGIN
                t_amountdue   := api.pkg_columnquery.numericvalue(rec.feeobjid, 'TotalOwing');

                UPDATE abclqs.renewal_info ri
                   SET ri.totalowing     = t_amountdue,
                       ri.paid           = 'Y',
                       ri.paymentbatch   = rec.paymentobjectid
                 WHERE ri.feeobjid = rec.feeobjid
                   LOG ERRORS INTO abclqs.err$_renewal_info
                           ('UPDATE')
                           REJECT LIMIT UNLIMITED;


                t_count1      := t_count1 + SQL%ROWCOUNT;

                SELECT ri.licensetypecode, NVL(sc.eligible, 'N')
                  INTO t_licensetypecode, t_eligible
                  FROM abclqs.renewal_info ri
                       LEFT OUTER JOIN abc.self_certification sc
                       ON (ri.licensenumber = sc.licensenumber
                       AND ri.licensetypecode = sc.licensetypecode
                       AND ri.expirationdate = sc.expirationdate)
                 WHERE ri.feeobjid = rec.feeobjid;

                DBMS_OUTPUT.put_line(   'jobid: '
                                     || rec.jobid);

                api.pkg_logicaltransactionupdate.endtransaction;
                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    t_sqlcode     := SQLCODE;
                    t_sqlerrm     := SQLERRM;
                    t_backtrace   := DBMS_UTILITY.format_error_backtrace;

                    api.pkg_logicaltransactionupdate.resettransaction;
                    ROLLBACK;

                    INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$,
                                                           e.ora_err_mesg$,
                                                           e.ora_err_tag$,
                                                           e.backtrace)
                         VALUES (t_sqlcode,
                                 SUBSTR(t_sqlerrm, 1, 2000),
                                 'upd_cert_payment',
                                 SUBSTR(t_backtrace, 1, 4000));

                    COMMIT;
                    DBMS_OUTPUT.put_line('ERROR');
            END;
        END LOOP;

        UPDATE abclqs.renewal_run_log rl
           SET rl.results     =
                      'Records Processed: '
                   || t_count1,
               rl.SQLERRM     = t_sqlerrm,
               rl.backtrace   = t_backtrace
         WHERE rl.seq = t_seq;

        api.pkg_logicaltransactionupdate.resettransaction;
        COMMIT;

        DBMS_OUTPUT.put_line(   'Records updated: '
                             || t_count1);
    END upd_cert_payment;


---------------------------------------------------------------------
    PROCEDURE upd_cert_penalty(a_penalty      IN VARCHAR2,
---------------------------------------------------------------------
                               a_start_date   IN DATE,
                               a_end_date     IN DATE,
                               a_batchseq     IN NUMBER DEFAULT NULL)
    IS
        t_count1      NUMBER := 0;
        t_sqlerrm     VARCHAR2(4000);
        t_backtrace   VARCHAR2(4000);
        t_sqlcode     NUMBER;
        t_seq         NUMBER;
        t_batchseq    NUMBER;
    BEGIN
        CASE
            WHEN a_batchseq IS NOT NULL THEN
                t_batchseq   := a_batchseq;
            ELSE
                SELECT MAX(batchseq) + 1
                  INTO t_batchseq
                  FROM abclqs.renewal_run_log;
        END CASE;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype,
                                              rl.startdate,
                                              rl.enddate,
                                              rl.batchseq)
             VALUES (   'upd_cert_penalty ('
                     || a_penalty
                     || ')',
                     a_start_date,
                     a_end_date,
                     t_batchseq)
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;

        DBMS_OUTPUT.put_line(   'upd_cert_penalty: '
                             || a_penalty);

        FOR lic
            IN (SELECT licensenumber, licensetypecode, expirationdate
                  FROM (WITH
                            batches
                            AS
                                (SELECT  /*+ materialize */
                                        *
                                   FROM (SELECT j.jobid, api.pkg_columnquery.VALUE(j.jobid, 'BatchType') batchtype
                                           FROM api.jobs j
                                          WHERE TRUNC(j.completeddate) BETWEEN a_start_date AND a_end_date) b
                                  WHERE NVL(b.batchtype, 'x') = a_penalty)
                          SELECT DISTINCT
                                 api.pkg_columnquery.VALUE(x.licensetypejobid, 'LicenseNumber')    licensenumber,
                                 api.pkg_columnquery.VALUE(x.licensetypejobid, 'LicenseTypeCode')  licensetypecode,
                                 api.pkg_columnquery.datevalue(x.licensetypejobid, 'ExpirationDate') expirationdate
                            FROM batches b
                                 JOIN sitespecific.licbatchlictype_xref_t x
                                 ON x.licensebatchjobid = b.jobid
                        ORDER BY LPAD(licensenumber, 7, ' ')))
        LOOP
            BEGIN
                UPDATE abclqs.renewal_info ri
                   SET ri.totalowing   = api.pkg_columnquery.numericvalue(ri.feeobjid, 'TotalOwing'),
                       ri.feeamount    = api.pkg_columnquery.numericvalue(ri.feeobjid, 'TotalFeeAmount')
                 WHERE ri.licensenumber = lic.licensenumber
                   AND ri.licensetypecode = lic.licensetypecode
                   AND ri.expirationdate = lic.expirationdate
                   LOG ERRORS INTO abclqs.err$_renewal_info
                           ('UPDATE')
                           REJECT LIMIT UNLIMITED;

                t_count1   := t_count1 + SQL%ROWCOUNT;

                COMMIT;
            EXCEPTION
                WHEN OTHERS THEN
                    t_sqlcode     := SQLCODE;
                    t_sqlerrm     := SQLERRM;
                    t_backtrace   := DBMS_UTILITY.format_error_backtrace;

                    api.pkg_logicaltransactionupdate.resettransaction;
                    ROLLBACK;

                    INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$,
                                                           e.ora_err_mesg$,
                                                           e.licensenumber,
                                                           e.backtrace)
                         VALUES (t_sqlcode,
                                 SUBSTR(t_sqlerrm, 1, 2000),
                                 lic.licensenumber,
                                 SUBSTR(t_backtrace, 1, 4000));

                    COMMIT;
            END;
        END LOOP;

        COMMIT;


        UPDATE abclqs.renewal_run_log rl
           SET rl.results     =
                      'Records Processed: '
                   || t_count1,
               rl.SQLERRM     = t_sqlerrm,
               rl.backtrace   = t_backtrace
         WHERE rl.seq = t_seq;

        COMMIT;
        DBMS_OUTPUT.put_line(   'Records updated: '
                             || t_count1);
    EXCEPTION
        WHEN OTHERS THEN
            t_sqlcode     := SQLCODE;
            t_sqlerrm     := SQLERRM;
            t_backtrace   := DBMS_UTILITY.format_error_backtrace;

            api.pkg_logicaltransactionupdate.resettransaction;
            ROLLBACK;

            INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$,
                                                   e.ora_err_mesg$,
                                                   e.ora_err_tag$,
                                                   e.backtrace)
                 VALUES (t_sqlcode,
                         SUBSTR(t_sqlerrm, 1, 2000),
                         'upd_cert_penalty',
                         SUBSTR(t_backtrace, 1, 4000));

            COMMIT;
    END upd_cert_penalty;

---------------------------------------------------------------------
    PROCEDURE upd_cert_license_issued(a_batchseq IN NUMBER DEFAULT NULL)
---------------------------------------------------------------------
    IS
        t_count1      NUMBER := 0;
        t_sqlerrm     VARCHAR2(4000);
        t_backtrace   VARCHAR2(4000);
        t_sqlcode     NUMBER;
        t_date        DATE;
        t_seq         NUMBER;
        t_batchseq    NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line('start upd_cert_license_issued: ');

        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;

        CASE
            WHEN a_batchseq IS NOT NULL THEN
                t_batchseq   := a_batchseq;
            ELSE
                SELECT MAX(batchseq) + 1
                  INTO t_batchseq
                  FROM abclqs.renewal_run_log;
        END CASE;

        INSERT INTO abclqs.renewal_run_log rl(rl.jobtype, rl.batchseq)
             VALUES ('upd_cert_license_issued', t_batchseq)
          RETURNING rl.seq
               INTO t_seq;

        COMMIT;

        FOR lts IN (SELECT ri.jobid,
                           ri.licensetypecode,
                           ltc.color,
                           TRUNC(api.pkg_columnquery.datevalue(ri.feeobjid, 'TransactionDate')) transactiondate
                      FROM abclqs.renewal_info ri
                           JOIN query.o_licensetypecategory ltc
                           ON (ltc.licensetypecode = ri.licensetypecode)
                     WHERE ri.paid = 'Y'
                       AND NVL(ri.issued, 'N') = 'N')
        LOOP
            -- look if license has been issued for this renewal activity
            FOR b
                IN (SELECT *
                      FROM (SELECT  /*+ materialize */
                                   api.pkg_columnquery.datevalue(x.licensebatchjobid, 'completeddate')
                                       completeddate,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'color')
                                       color,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'BatchType')
                                       batchtype,
                                   api.pkg_columnquery.VALUE(x.licensebatchjobid, 'StatusDescription')
                                       statusdescription
                              FROM sitespecific.licbatchlictype_xref_t x
                             WHERE x.licensetypejobid = lts.jobid) b
                     WHERE b.batchtype = 'PRODUCE LICENSES'
                       AND TRUNC(b.completeddate) >= TRUNC(lts.transactiondate)
                       AND b.color = lts.color
                       AND b.statusdescription = 'Complete')
            LOOP
                UPDATE abclqs.renewal_info ri
                   SET ri.issued   = 'Y'
                 WHERE ri.jobid = lts.jobid
                   AND ri.licensetypecode = lts.licensetypecode
                   LOG ERRORS INTO abclqs.err$_renewal_info
                           ('UPDATE')
                           REJECT LIMIT UNLIMITED;

                t_count1   := t_count1 + SQL%ROWCOUNT;
                COMMIT;
            END LOOP;
        END LOOP;

        UPDATE abclqs.renewal_run_log rl
           SET rl.results     =
                      'Records Processed: '
                   || t_count1,
               rl.SQLERRM     = t_sqlerrm,
               rl.backtrace   = t_backtrace
         WHERE rl.seq = t_seq;

        COMMIT;

        DBMS_OUTPUT.put_line(   'Records updated: '
                             || t_count1);
    EXCEPTION
        WHEN OTHERS THEN
            t_sqlcode     := SQLCODE;
            t_sqlerrm     := SQLERRM;
            t_backtrace   := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO abclqs.err$_renewal_info e(e.ora_err_number$,
                                                   e.ora_err_mesg$,
                                                   e.ora_err_tag$,
                                                   e.backtrace,
                                                   e.createddate)
                 VALUES (t_sqlcode,
                         SUBSTR(t_sqlerrm, 1, 2000),
                         'upd_cert_license_issued',
                         SUBSTR(t_backtrace, 1, 4000),
                         SYSDATE);

            COMMIT;
    END upd_cert_license_issued;
END;
/
