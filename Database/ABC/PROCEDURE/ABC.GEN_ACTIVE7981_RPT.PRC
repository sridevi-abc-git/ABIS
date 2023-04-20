CREATE OR REPLACE PROCEDURE ABC.gen_active7981_rpt(
    a_maildate      DATE DEFAULT NULL,
    a_duedate       DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)
AS
    -- **************************************************************************
    -- File:        GEN_ACTIVE7981_RPT.PRC
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

    -- For Active 79/81 List Report, no parameter is needed.

    t_ptfeeobjectlist   api.udt_objectlist;
    t_count             PLS_INTEGER := 0;
    t_yr                VARCHAR2(2) := TO_CHAR(CURRENT_DATE, 'YY');

    -- Notice Report
    t_maildate          DATE := TRUNC(NVL(a_maildate, CURRENT_DATE));
    t_duedate           DATE := TRUNC(NVL(a_duedate, CURRENT_DATE));
    t_firstnotice       VARCHAR2(1) := NVL(UPPER(a_firstnotice), 'Y');
    t_issuedate         DATE := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');

    t_startdate         DATE;
    t_enddate           DATE;
    t_transdatestart    DATE;
    t_transdateend      DATE;
BEGIN
    t_issuedate        := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');
    t_startdate        := ADD_MONTHS(TO_DATE('07/01/' || t_yr, 'mm/dd/yy'), -12);
    t_enddate          := TO_DATE('06/30/' || t_yr, 'mm/dd/yy');
    t_transdatestart   :=
        ADD_MONTHS(TO_DATE('04/15/' || t_yr, 'mm/dd/yy'), -12);
    t_transdateend     := TO_DATE('04/15/' || t_yr, 'mm/dd/yy');


    -- Get Primary Licenses
    INSERT INTO abc.active7981_rpt(filenum,
                                   licensee,
                                   status,
                                   district,
                                   ltcode,
                                   ltstatus,
                                   ltexpdate,
                                   ltfeecode,
                                   ltissdate,
                                   address,
                                   maildate,
                                   duedate,
                                   firstnotice,
                                   startdate,
                                   enddate,
                                   issuedate,
                                   transdatestart,
                                   transdateend)
        SELECT DISTINCT                                          --125 records
               l.externalfilenum
                   AS filenum,
               l.primarylicensee
                   AS licensee,
               lt.statusname
                   AS status,
               lt.district
                   AS district         --, L.basefileofficecodecorral district
                              ,
               lt.licensetypecode
                   AS ltcode,
               lt.statusname
                   AS ltstatus,
               TRUNC(lt.expirationdate)
                   AS ltexpdate,
               qlt.gallonagerangefeecode
                   ltfeecode,
               TRUNC(NVL(lt.issuedate,
                         (SELECT js.effectivestartdate
                            FROM extension.jobstatuschange_t js
                           WHERE js.jobid = lt.objectid
                             AND js.mostrecent = 'Y')))
                   AS ltissdate,
               UPPER(
                   NVL2(
                       lt.mailaddress1stof2lines || lt.mailaddress2ndof2lines,
                          lt.mailaddress1stof2lines
                       || CHR(13)
                       || lt.mailaddress2ndof2lines
                       || CHR(13),
                          lt.premaddress1stof2lines
                       || CHR(13)
                       || lt.premaddress2ndof2lines
                       || CHR(13)))
                   AS address,
               t_maildate,
               t_duedate,
               t_firstnotice,
               t_startdate,
               t_enddate,
               t_issuedate,
               t_transdatestart,
               t_transdateend
          FROM mart.license  l
               JOIN mart.licenselicensetyperel ll
                   ON ll.licensejobid = l.jobid
               JOIN mart.licensetype lt ON lt.licensejobid = ll.licensejobid
               JOIN
               (SELECT b.objectid,
                       b.objectdefid
                           jobtypeid,
                       e.statusid,
                       api.pkg_columnquery.VALUE(b.objectid,
                                                 'GallonageRangeFeeCode')
                           gallonagerangefeecode
                  FROM possedata.readableobjects  b
                       JOIN workflow.jobs e ON e.jobid = b.objectid
                 WHERE b.objectdefid = 329416) qlt
                   ON qlt.objectid = lt.objectid
         WHERE lt.licensenumber IS NOT NULL
           AND NVL(lt.primarylicensee, lt.primarydba) IS NOT NULL
           AND lt.licensetypecode IS NOT NULL
           AND lt.licensetypecode = '79'
           AND lt.statusname IN ('ACTIVE',
                                 'R64B',
                                 'REVPEN',
                                 'SLMSHD',
                                 'SUREND',
                                 'SUSPEN');

    -- COMMIT;  -- Use of Global Temporary Tables does not require COMMIT


    -- Get Secondary Licenses
    -- Note: I broke up the original UNION for performance.

    INSERT INTO abc.active7981_rpt(filenum,
                                   licensee,
                                   status,
                                   district,
                                   ltcode,
                                   ltstatus,
                                   ltexpdate,
                                   ltfeecode,
                                   ltissdate,
                                   address,
                                   maildate,
                                   duedate,
                                   firstnotice,
                                   startdate,
                                   enddate,
                                   issuedate,
                                   transdatestart,
                                   transdateend)
          SELECT DISTINCT
                 l.externalfilenum
                     AS filenum,
                 l.primarylicensee
                     AS licensee --, upper(nvl(L.primarylicensee,L.primarydba)) licensee
                                ,
                 l.statusname
                     AS status,
                 lt.district
                     AS district       --, L.basefileofficecodecorral district
                                ,
                 oltc.licensetypecode
                     AS ltcode,
                 lt.statusname
                     AS ltstatus,
                 TRUNC(lt.expirationdate)
                     AS ltexpdate,
                 qlt.gallonagerangefeecode
                     AS ltfeecode       --, LT.GallonageRangeFeeCode ltfeecode
                                 ,
                 TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                     AS ltissdate,
                 UPPER(
                     NVL2(
                         lt.mailaddress1stof2lines || lt.mailaddress2ndof2lines,
                            lt.mailaddress1stof2lines
                         || CHR(13)
                         || lt.mailaddress2ndof2lines
                         || CHR(13),
                            lt.premaddress1stof2lines
                         || CHR(13)
                         || lt.premaddress2ndof2lines
                         || CHR(13)))
                     address,
                 t_maildate,
                 t_duedate,
                 t_firstnotice,
                 t_startdate,
                 t_enddate,
                 t_issuedate,
                 t_transdatestart,
                 t_transdateend
            FROM mart.license l
                 JOIN mart.licenselicensetyperel ll
                     ON ll.licensejobid = l.jobid
                 JOIN mart.licensetype lt ON lt.licensejobid = ll.licensejobid
                 JOIN
                 (SELECT b.objectid, b.objectdefid jobtypeid, e.statusid
                    FROM possedata.readableobjects b
                         JOIN workflow.jobs e ON e.jobid = b.objectid
                   WHERE b.objectdefid = 325227) ql
                     ON ql.objectid = l.jobid
                 JOIN
                 (SELECT b.objectid,
                         b.objectdefid
                             jobtypeid,
                         e.statusid,
                         api.pkg_columnquery.VALUE(b.objectid,
                                                   'GallonageRangeFeeCode')
                             AS gallonagerangefeecode
                    FROM possedata.readableobjects b
                         JOIN workflow.jobs e ON e.jobid = b.objectid
                   WHERE b.objectdefid = 329416) qlt
                     ON qlt.objectid = lt.objectid
                 JOIN mart.licensetypeltcatsecondary slt
                     ON slt.licensetypejobid = lt.objectid
                 JOIN mart.licensetypecategory oltc
                     ON oltc.objectid = slt.licensetypecategoryobjectid
                 JOIN api.jobstatuses js1
                     ON js1.jobtypeid = ql.jobtypeid
                    AND js1.statusid = ql.statusid
                    AND js1.statustype IN ('O', 'I')
                 JOIN api.jobstatuses js2
                     ON js2.jobtypeid = qlt.jobtypeid
                    AND js2.statusid = qlt.statusid
                    AND js2.statustype IN ('O', 'I')
                 LEFT OUTER JOIN extension.jobstatuschange_t jsc
                     ON jsc.jobid = qlt.objectid
                    AND jsc.mostrecent = 'Y'
           WHERE l.externalfilenum IS NOT NULL
             AND l.primarylicensee IS NOT NULL
             AND lt.licensetypecode IS NOT NULL
             --  AND QLT.GallonageRangeFeeCode IS NOT NULL
             AND oltc.licensetypecode IN '81'
             AND slt.status IN ('ACTIVE',
                                'R64B',
                                'REVPEN',
                                'SLMSHD',
                                'SUREND',
                                'SUSPEN')
        ORDER BY filenum;
--commit;

END gen_active7981_rpt;
/


GRANT EXECUTE ON ABC.GEN_ACTIVE7981_RPT TO POSSEEXTENSIONS;

GRANT EXECUTE ON ABC.GEN_ACTIVE7981_RPT TO PUBLIC;
