CREATE OR REPLACE PROCEDURE ABC."GEN_SECONDRENEWAL_RPT"(
    a_lbjobid      IN api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        GEN_SECONDRENEWAL_RPT.PRC
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
    -- Parameter is License Batch JobID

    -- Generate data for the Second Renewal Reports:
    --  * Second Renewal Notice
    --  * Second Renewal Part 1 (RP040) - Ren Due/Paid Report
    --  * Second Renewal Part 2 (RP091) - Late Notice Report
    --

    t_feeobjectids   api.udt_objectlist;
BEGIN
    DELETE FROM abc.secondrenewal_rpt
          WHERE lbjobid = a_lbjobid
             OR reportdate < TRUNC(CURRENT_DATE);

    FOR lictype
        IN (SELECT lb.jobid
                       lbjobid,
                   l.jobid
                       lcjobid,
                   lt.jobid
                       ltjobid,
                   lb.expirationdate,
                   lt.renewaldate,
                   lt.licensenumber
                       licensenum,
                   l.statusname
                       licstatus,
                   lt.licensetypecode
                       ltcode,
                   UPPER(SUBSTR(lt.primarylicensee, 1, 50))
                       licensee,
                   --lt.premisescity premcity,
                   NVL(l.mailingaddresscity, l.premaddressuscity)
                       premcity, /* Per Licensing this should have been Mailing address City */
                   --lt.premaddresszipcode premzip,
                   NVL(l.mailingaddresszipcode, l.premaddresszipcode)
                       premzip, /* Per Licensing this should have been Mailing address Zip*/
                   lt.jobstatus
                       ltstatus,
                   lt.hassecondary
                       ltmi,
                   lt.secondarylicensetypecount
                       ltdup,
                   lt.feeschedulecode
                       ltfeecode
              FROM query.j_licensebatch  lb
                   JOIN sitespecific.licbatchlictype_xref_t rlb
                       ON rlb.licensebatchjobid = lb.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = rlb.licensetypejobid
                   JOIN query.r_licenselicensetype rlt
                       ON rlt.licensetypejobid = lt.jobid
                   JOIN query.j_license l ON l.jobid = rlt.licensejobid
                   /* per Josh, license status should not be used.  8/17/2011 Bee
                   join   api.jobstatuses js1 on js1.jobtypeid = l.jobtypeid
                          and js1.statusid = l.statusid and js1.statustype in ('O','I')
                          */
                   JOIN api.jobstatuses js2
                       ON js2.jobtypeid = lt.jobtypeid
                      AND js2.statusid = lt.statusid
                      AND js2.statustype IN ('O', 'I')
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = lt.jobid
                      AND jsc.mostrecent = 'Y'
             WHERE lb.jobid = a_lbjobid
               AND lb.batchtype = '2ND RENEWAL NOTICES')
    LOOP
        -- get all fees related to jobid.
        sitespecific.pkg_fees.getfeesforjob(lictype.ltjobid,
                                            NULL,
                                            t_feeobjectids);

        FOR slt
            IN (SELECT ltc.licensetypecode ltcode
                  FROM query.r_licensetypeltcatsecondary  x
                       JOIN query.o_licensetypecategory ltc
                           ON ltc.objectid = x.licensetypecategoryobjectid
                 WHERE x.licensetypejobid = lictype.ltjobid
                UNION
                SELECT lictype.ltcode ltcode FROM DUAL)
        LOOP
            INSERT INTO abc.secondrenewal_rpt(lbjobid,
                                              lcjobid,
                                              ltjobid,
                                              feeobjectid,
                                              feeid,
                                              expiredate,
                                              renewaldate,
                                              licensenum,
                                              licstatus,
                                              ltcode,
                                              licensee,
                                              premcity,
                                              premzip,
                                              ltstatus,
                                              ltmi,
                                              ltdup,
                                              ltfeecode,
                                              feeamt,
                                              paidamt,
                                              adjamt,
                                              totalfee,
                                              totalowing,
                                              feedescr,
                                              gldescr,
                                              penalty50,
                                              iscredited,
                                              process_code,
                                              reportdate)
                SELECT lictype.lbjobid,
                       lictype.lcjobid,
                       lictype.ltjobid,
                       f.objectid
                           feeobjectid,
                       f.feeid
                           feeid,
                       lictype.expirationdate,
                       lictype.renewaldate,
                       f.licensenumberexpression
                           licensenum,
                       lictype.licstatus,
                       f.licensetypecodeexpression
                           ltcode,
                       lictype.licensee,
                       lictype.premcity,
                       lictype.premzip,
                       lictype.ltstatus,
                       f.ismaster
                           ltmi,
                       f.secondarycount
                           ltdup,
                       lictype.ltfeecode,
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
                       f.feescheduletransactioncode
                           feedescr,
                       f.glaccountdescription
                           gldescr,
                       NVL(
                           abc.gen_secondrenewal_ltpenalty(fs.objectid,
                                                           f.ismaster,
                                                           f.secondarycount),
                           0)
                           penalty50,
                       CASE
                           WHEN NVL(f.paidamount, 0) = 0 THEN ' '
                           ELSE '*'
                       END
                           iscredited,
                       CASE
                           WHEN f.totalowing > 0 THEN 'REN DUE'
                           ELSE 'REN PAID'
                       END
                           process_code,
                       TRUNC(CURRENT_DATE)
                           reportdate
                  FROM query.o_fee  f
                       JOIN query.r_feelicensefeeschedule r
                           ON r.feeobjectid = f.objectid
                       JOIN
                       TABLE(CAST(t_feeobjectids AS api.udt_objectlist)) x
                           ON x.objectid = f.objectid
                       LEFT OUTER JOIN query.o_feeschedule fs
                           ON fs.objectid = r.licensefeescheduleid
                 WHERE f.feeid = abc.gen_secondrenewal_currentfee(
                                     lictype.ltjobid,
                                     slt.ltcode,
                                     'REN50',
                                     lictype.expirationdate)
                   AND f.feescheduletransactionfeeactiv LIKE 'REN%';
        END LOOP;
    END LOOP;

    UPDATE secondrenewal_rpt
       SET totaldue   = totalowing,
           unpaidrenewal   =
               DECODE(SIGN(totalfee - penalty50 - paidamt),
                      -1, 0,
                      totalfee - penalty50 - paidamt),
           fiftypctpenalty   =
               DECODE(SIGN(totalfee - penalty50 - paidamt),
                      -1, totalowing,
                      penalty50);
END gen_secondrenewal_rpt;
/


GRANT EXECUTE ON ABC.GEN_SECONDRENEWAL_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_SECONDRENEWAL_RPT TO PUBLIC;
