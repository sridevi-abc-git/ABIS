CREATE OR REPLACE PROCEDURE ABC.gen_rp037_rpt(a_expdate IN DATE)
IS
    -- **************************************************************************
    -- File:        GEN_RP037_RPT.PRC
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
    --CREATE OR REPLACE procedure ABC.gen_rp037_rpt (a_lbjobid  IN api.pkg_definition.udt_id) as
    -- parameter a_lbjobid is license batch jobid

    -- Generate data for the First Renewal Reports :
    --  * First Renewal Notice
    --  * First Renewal (RP036) Paid Renewals
    --  * First Renewal (RP037) Exceptions
    --  * First Renewal (RP038) Due For Renewal
    --  * First Renewal (RP039) Summary
    --
    t_ptobjectlist   api.udt_objectlist;
    t_expdate        DATE := TRUNC(a_expdate);
    t_reportdate     DATE := TRUNC(SYSDATE);
    t_feeobjectids   api.udt_objectlist;
BEGIN
    DELETE FROM abc.firstrenewal_rpt037
          WHERE expiredate = a_expdate
             OR reportdate < TRUNC(SYSDATE);

    COMMIT;

    FOR lictype
        IN (SELECT DISTINCT
                   --lb.jobid
                   NULL                                     lbjobid,
                   l.jobid                                  lcjobid,
                   lt.jobid                                 ltjobid,
                   --null expirationdate,
                   lt.expirationdate                        expirationdate,
                   l.licensenumber                          licensenum,
                   l.statusname                             licstatus,
                   lt.licensetypecode                       ltcode,
                   UPPER(SUBSTR(lt.primarylicensee, 1, 25)) licensee,
                   lt.premisescity                          premcity,
                   lt.premaddresszipcode                    premzip,
                   lt.jobstatus                             ltstatus,
                   lt.hassecondary                          ltmi,
                   lt.secondarylicensetypecount             ltdup,
                   lt.feeschedulecode                       ltfeecode
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindex(
                               'j_LicenseType',
                               'dup_ExpirationDate',
                               TO_CHAR(t_expdate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                   x
                   JOIN api.objects o ON o.objectid = x.objectid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = o.objectid
                      AND lt.objectdeftypeid = 2 --this is used to tell the Oracle optimizer to use the correct index.
                   JOIN query.r_licenselicensetype r
                       ON r.licensetypejobid = o.objectid
                   JOIN query.j_license l ON l.jobid = r.licensejobid
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = o.objectid
                      AND jsc.mostrecent = 'Y'
             WHERE l.statusid IN (SELECT statusid
                                    FROM api.jobstatuses js1
                                   WHERE js1.jobtypeid = l.jobtypeid
                                     AND js1.statustype IN ('O', 'I'))
               AND lt.statusid IN (SELECT statusid
                                     FROM api.jobstatuses js2
                                    WHERE js2.jobtypeid = lt.jobtypeid
                                      AND js2.statustype IN ('O', 'I'))--and l.licensenumber in ('475646','422931', '431389', '466888', '414243', '392149')
                                                                       )
    LOOP
        -- get all fees related to jobid.
        sitespecific.pkg_fees.getfeesforjob(lictype.ltjobid,
                                            NULL,
                                            t_feeobjectids);

        FOR i IN 1 .. t_feeobjectids.COUNT
        LOOP
            INSERT INTO abc.firstrenewal_rpt037(lbjobid,
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
                                                ltpenalty)
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
                           ltpenalty
                  FROM query.o_fee  f
                       JOIN query.r_feelicensefeeschedule r
                           ON r.feeobjectid = f.objectid
                       LEFT OUTER JOIN query.o_feeschedule fs
                           ON fs.objectid = r.licensefeescheduleid
                 WHERE f.objectid = t_feeobjectids(i).objectid
                   AND f.feescheduletransactionfeeactiv = 'REN';
        END LOOP;
    END LOOP;

    FOR ren IN (  SELECT SUM(r.ltpenalty) licpenalty, r.lbjobid, r.lcjobid
                    FROM abc.firstrenewal_rpt037 r
                GROUP BY r.lbjobid, r.lcjobid)
    LOOP
        UPDATE abc.firstrenewal_rpt037
           SET licpenalty   = ren.licpenalty
         WHERE lbjobid = ren.lbjobid
           AND lcjobid = ren.lcjobid;
    END LOOP;
END gen_rp037_rpt;


--grant execute on abc.gen_rp037_rpt to public;
--grant execute on abc.gen_rp037_rpt to posseextensions;
/


GRANT EXECUTE ON ABC.GEN_RP037_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_RP037_RPT TO PUBLIC;
