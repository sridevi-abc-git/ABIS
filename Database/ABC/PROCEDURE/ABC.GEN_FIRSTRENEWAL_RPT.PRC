CREATE OR REPLACE PROCEDURE ABC."GEN_FIRSTRENEWAL_RPT"(
    a_lbjobid      IN api.pkg_definition.udt_id)
AS
    -- **************************************************************************
    -- File:        GEN_FIRSTRENEWAL_RPT.PRC
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
    -- parameter a_lbjobid is license batch jobid

    -- Generate data for the First Renewal Reports :
    --  * First Renewal Notice
    --  * First Renewal (RP036) Paid Renewals
    --  * First Renewal (RP037) Exceptions
    --  * First Renewal (RP038) Due For Renewal
    --  * First Renewal (RP039) Summary
    --

    t_feeobjectids   api.udt_objectlist;
BEGIN
    DELETE FROM abc.firstrenewal_rpt
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
                   l.licensenumber
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
                   /* per josh as for the secondary renewal 8/19Bee
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
               AND lb.batchtype = '1ST RENEWAL NOTICES')
    LOOP
        -- get all fees related to jobid.
        sitespecific.pkg_fees.getfeesforjob(lictype.ltjobid,
                                            NULL,
                                            t_feeobjectids);

        FOR i IN 1 .. t_feeobjectids.COUNT
        LOOP
            INSERT INTO abc.firstrenewal_rpt(lbjobid,
                                             lcjobid,
                                             ltjobid,
                                             feeobjectid,
                                             feeid,
                                             expiredate,
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
                                             isadjusted,
                                             reportdate,
                                             ltpenalty,
                                             transactiondate)
                SELECT lictype.lbjobid,
                       lictype.lcjobid,
                       lictype.ltjobid,
                       f.objectid
                           feeobjectid,
                       f.feeid
                           feeid,
                       lictype.expirationdate,
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
                       f.feecode
                           ltfeecode,
                       f.amount
                           feeamt,
                       f.paidamount
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
                       CASE
                           WHEN NVL(f.paidamount, 0) = 0 THEN ' '
                           ELSE '*'
                       END
                           isadjusted,
                       TRUNC(CURRENT_DATE)
                           reportdate,
                       DECODE(
                           SIGN(f.totalowing),
                           1, abc.gen_firstrenewal_ltpenalty(
                                  fs.objectid,
                                  f.ismaster,
                                  f.secondarycount),
                           0)
                           ltpenalty,
                       f.transactiondate
                  FROM query.o_fee  f
                       JOIN query.r_feelicensefeeschedule r
                           ON r.feeobjectid = f.objectid
                       LEFT OUTER JOIN query.o_feeschedule fs
                           ON fs.objectid = r.licensefeescheduleid
                 WHERE f.objectid = t_feeobjectids(i).objectid
                   AND f.feescheduletransactionfeeactiv = 'REN';
        END LOOP;
    END LOOP;

    DELETE FROM abc.firstrenewal_rpt fr
          WHERE fr.transactiondate < SYSDATE - 30; -- eliminate the previous year's fees from Renewal Notices

    --Moved here by pawan to fix WO 5000

    FOR ren IN (  SELECT SUM(r.ltpenalty) licpenalty, r.lbjobid, r.lcjobid
                    FROM abc.firstrenewal_rpt r
                GROUP BY r.lbjobid, r.lcjobid)
    LOOP
        UPDATE abc.firstrenewal_rpt
           SET licpenalty   = ren.licpenalty
         WHERE lbjobid = ren.lbjobid
           AND lcjobid = ren.lcjobid;
    END LOOP;
--delete from abc.firstrenewal_rpt fr
-- where FR.TRANSACTIONDATE < SYSDATE - 30;

END gen_firstrenewal_rpt;
/


GRANT EXECUTE ON ABC.GEN_FIRSTRENEWAL_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_FIRSTRENEWAL_RPT TO PUBLIC;
