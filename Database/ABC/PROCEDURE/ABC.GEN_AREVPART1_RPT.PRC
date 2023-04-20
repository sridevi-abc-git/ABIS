CREATE OR REPLACE PROCEDURE ABC."GEN_AREVPART1_RPT"(
    a_lbjobid       api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        GEN_AREVPART1_RPT.PRC
    -- Author:      CX
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Date                  Comment
    -- 08/20/2018 TJL         Initial Check-in
    -- **************************************************************************
    /* parameter a_lbjobid is license batch jobid  */
    /* generate auto revocation - part 1 report */
    /* test license batch jobid (228003, 228016)   */

    t_feeobjectids   api.udt_objectlist;
    t_count          NUMBER;
BEGIN
    t_count   := 0;

    DELETE FROM abc.arevpart1_rpt
          WHERE lbjobid = a_lbjobid
             OR reportdate < TRUNC(CURRENT_DATE);

    COMMIT;

    FOR lictype
        IN (  SELECT lb.jobid                               lbjobid,
                     lt.jobid                               ltjobid,
                     lb.expirationdate,
                     lt.licensenumber                       licensenum,
                     lt.licensetypecode,
                     UPPER(SUBSTR(lt.primarylicensee, 1, 25)) licensee,
                     lt.premisescity                        city,
                     lt.jobstatus                           ltstatus,
                     lt.hassecondary                        ltmi,
                     lt.secondarylicensetypecount           ltdup,
                     lt.feeschedulecode                     ltfeecode
                FROM query.j_licensebatch lb
                     JOIN sitespecific.licbatchlictype_xref_t rlb
                         ON rlb.licensebatchjobid = lb.jobid
                     JOIN query.j_licensetype lt
                         ON lt.jobid = rlb.licensetypejobid
                     JOIN query.r_licenselicensetype rlt
                         ON rlt.licensetypejobid = lt.jobid
                     JOIN query.j_license l ON l.jobid = rlt.licensejobid
               WHERE lb.jobid = a_lbjobid
            ORDER BY licensenum, lt.licensetypecode)
    LOOP
        t_count   := t_count + 1;
        sitespecific.pkg_fees.getfeesforjob(lictype.ltjobid,
                                            NULL,
                                            t_feeobjectids);

        FOR i IN 1 .. t_feeobjectids.COUNT
        LOOP
            INSERT INTO abc.arevpart1_rpt(lbjobid,
                                          ltjobid,
                                          feeobjectid,
                                          expiredate,
                                          licensee,
                                          licensenum,
                                          ltcode,
                                          ltstatus,
                                          ltmi,
                                          ltdup,
                                          city,
                                          feeamt,
                                          paidamt,
                                          adjamt,
                                          totalfee,
                                          totalowing,
                                          iscredited,
                                          process_code,
                                          testfield,
                                          reportdate)
                  SELECT lictype.lbjobid,
                         lictype.ltjobid,
                         f.objectid
                             feeobjectid,
                         lictype.expirationdate,
                         lictype.licensee,
                         f.licensenumberexpression
                             licensenum,
                         f.licensetypecodeexpression
                             ltcode,
                         lictype.ltstatus,
                         f.ismaster
                             ltmi,                             --lictype.ltmi,
                         f.secondarycount
                             ltdup,                           --lictype.ltdup,
                         lictype.city,
                         f.amount
                             feeamt,
                         ABS(f.paidamount)
                             paidamt,
                         f.adjustedamount
                             adjamt,
                         f.totalfeeamount
                             totalfee,
                         f.totalowing
                             totalowing,
                         CASE WHEN ABS(f.paidamount) > 0 THEN '*' ELSE ' ' END
                             iscredited,
                         CASE
                             WHEN ABS(f.paidamount) > 0 THEN 'REN PAID'
                             ELSE 'REN DUE'
                         END
                             process,
                            'LTLicNum='
                         || lictype.licensetypecode
                         || '-'
                         || TRIM(TO_CHAR(lictype.licensenum))
                         || ' , '
                         || 'FEESCHEDULETRANSACTIONFEEACTIV='
                         || f.feescheduletransactionfeeactiv
                             testfield,
                         TRUNC(CURRENT_DATE)
                             reportdate
                    FROM query.o_fee f
                         JOIN query.r_feelicensefeeschedule r
                             ON r.feeobjectid = f.objectid
                         LEFT OUTER JOIN query.o_feeschedule fs
                             ON fs.objectid = r.licensefeescheduleid
                   WHERE f.objectid = t_feeobjectids(i).objectid
                     AND f.feescheduletransactionfeeactiv = 'REN100' -- production
                --and f.feescheduletransactionfeeactiv like 'REN%'  -- testing
                ORDER BY licensenum, ltcode;
        END LOOP;

        IF MOD(t_count, 10) = 0 THEN
            COMMIT;
        END IF;
    END LOOP;

    COMMIT;
END gen_arevpart1_rpt;

/* grant execute on abc.gen_arevpart1_rpt to public; */
/


GRANT EXECUTE ON ABC.GEN_AREVPART1_RPT TO POSSEEXTENSIONS;
