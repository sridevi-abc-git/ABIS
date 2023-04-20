CREATE OR REPLACE PROCEDURE ABC.gen_active7981_rpt_qa(
    a_maildate      DATE DEFAULT NULL,
    a_duedate       DATE DEFAULT NULL,
    a_firstnotice   VARCHAR2 DEFAULT NULL)
AS
    -- **************************************************************************
    -- File:        GEN_ACTIVE7981_RPT_QA.PRC
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
    IF t_issuedate > CURRENT_DATE THEN
        t_yr   := TO_CHAR(ADD_MONTHS(CURRENT_DATE, -12), 'YY');
    END IF;

    t_issuedate        := TO_DATE('05/31/' || t_yr, 'mm/dd/yy');
    t_startdate        := ADD_MONTHS(TO_DATE('07/01/' || t_yr, 'mm/dd/yy'), -12);
    t_enddate          := TO_DATE('06/30/' || t_yr, 'mm/dd/yy');
    t_transdatestart   :=
        ADD_MONTHS(TO_DATE('04/15/' || t_yr, 'mm/dd/yy'), -12);
    t_transdateend     := TO_DATE('04/15/' || t_yr, 'mm/dd/yy');

    --  delete from abc.active7981_rpt;
    DELETE FROM abc.active7981_rpt_qa;

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    COMMIT;                                 --comment it out for regular table

    --loop through all license types.
    FOR c_lictype
        IN (SELECT DISTINCT
                   lt.jobid
                       jobid,
                   lt.licensenumber
                       filenum,
                   UPPER(NVL(lt.primarylicensee, lt.primarydba))
                       licensee,
                   lt.statusname
                       status,
                   lt.basefileofficecodecorral
                       district,
                   lt.licensetypecode
                       ltcode,
                   lt.statusname
                       ltstatus,
                   TRUNC(lt.expirationdate)
                       ltexpdate,
                   lt.gallonagerangefeecode
                       ltfeecode,
                   TRUNC(NVL(lt.issuedate,
                             (SELECT js.effectivestartdate
                                FROM extension.jobstatuschange_t js
                               WHERE js.jobid = lt.jobid
                                 AND js.mostrecent = 'Y')))
                       ltissdate,
                   UPPER(
                       NVL(lt.licensemailingaddress2lines,
                           lt.licensepremisesaddress2lines))
                       address
              FROM query.j_licensetype  lt
                   JOIN query.r_licenselicensetype rllt
                       ON lt.jobid = rllt.licensetypejobid
             WHERE lt.licensenumber IS NOT NULL
               AND NVL(lt.primarylicensee, lt.primarydba) IS NOT NULL
               AND lt.licensetypecode IS NOT NULL
               AND lt.licensetypecode = '79'
               AND lt.statusname IN ('ACTIVE',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD',
                                     'SUREND',
                                     'SUSPEN')
            UNION
            SELECT DISTINCT
                   l.jobid
                       jobid,
                   l.licensenumber
                       filenum,
                   UPPER(NVL(l.primarylicensee, l.primarydba))
                       licensee,
                   l.statusname
                       status,
                   l.basefileofficecodecorral
                       district,
                   oltc.licensetypecode
                       ltcode,
                   lt.statusname
                       ltstatus,
                   TRUNC(lt.expirationdate)
                       ltexpdate,
                   lt.gallonagerangefeecode
                       ltfeecode,
                   TRUNC(NVL(lt.issuedate, jsc.effectivestartdate))
                       ltissdate,
                   UPPER(
                       NVL(lt.licensemailingaddress2lines,
                           lt.licensepremisesaddress2lines))
                       address
              FROM query.j_license  l
                   JOIN query.r_licenselicensetype rlt
                       ON rlt.licensejobid = l.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = rlt.licensetypejobid
                   JOIN query.r_licensetypeltcatsecondary slt
                       ON slt.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory oltc
                       ON oltc.objectid = slt.licensetypecategoryobjectid
                   JOIN api.jobstatuses js1
                       ON js1.jobtypeid = l.jobtypeid
                      AND js1.statusid = l.statusid
                      AND js1.statustype IN ('O', 'I')
                   JOIN api.jobstatuses js2
                       ON js2.jobtypeid = lt.jobtypeid
                      AND js2.statusid = lt.statusid
                      AND js2.statustype IN ('O', 'I')
                   LEFT OUTER JOIN extension.jobstatuschange_t jsc
                       ON jsc.jobid = lt.jobid
                      AND jsc.mostrecent = 'Y'
             WHERE l.licensenumber IS NOT NULL
               AND NVL(l.primarylicensee, l.primarydba) IS NOT NULL
               AND lt.licensetypecode IS NOT NULL
               -- and    lt.gallonagerangefeecode is not null
               AND oltc.licensetypecode IN '81'
               AND lt.statusname IN ('ACTIVE',
                                     'R64B',
                                     'REVPEN',
                                     'SLMSHD',
                                     'SUREND',
                                     'SUSPEN'))
    LOOP
        SELECT COUNT(*)
          INTO t_count
          --    from   abc.active7981_rpt
          FROM abc.active7981_rpt_qa
         WHERE filenum = c_lictype.filenum
           AND ltcode = c_lictype.ltcode
           AND ROWNUM = 1;

        IF t_count = 0 THEN
            INSERT INTO abc.active7981_rpt_qa-- create table active7981_rpt_qa as select * from active7981_rpt;
                                             (filenum,
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
                 VALUES (c_lictype.filenum,
                         c_lictype.licensee,
                         c_lictype.status,
                         c_lictype.district,
                         c_lictype.ltcode,
                         c_lictype.ltstatus,
                         c_lictype.ltexpdate,
                         c_lictype.ltfeecode,
                         c_lictype.ltissdate,
                         c_lictype.address,
                         t_maildate,
                         t_duedate,
                         t_firstnotice,
                         t_startdate,
                         t_enddate,
                         t_issuedate,
                         t_transdatestart,
                         t_transdateend);
        END IF;
    END LOOP;

    -- for testing only; global temporary tables will be used in production; no commit command is needed;
    COMMIT;
END gen_active7981_rpt_qa;
/
