CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_reprintlicenses
IS
    -- **************************************************************************
    -- File:        PKG_REPRINTLICENSES.PKB
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
    /**************************************************************************
    * Global variables declared
    * g_OwnerLineLength is the length in charaters that the Lines in the nested
    * data window for the license report are limited to
    ***************************************************************************/
    g_ownerlinelength   INTEGER := 35;

    PROCEDURE manualproducelicense_fix(a_objectid udt_id)
    IS
        temp              api.udt_objectlist;
        t_pagenumber      INTEGER := 1;
        t_licensenumber   INTEGER;
        t_lines           INTEGER;
        t_counttemp       INTEGER;
        t_jobid           INTEGER;
        t_previousjobid   INTEGER;
        t_nextjobid       INTEGER;
        t_continue        BOOLEAN;
    BEGIN
        -- DELETE PinkAndGreenLicense_FIX;

        COMMIT;

        -- Run SQL and either out it through a variable or place it directly into the GTT
        INSERT INTO pinkandgreenlicense_fix(licensetypename,
                                            licensee,
                                            lic_dba,
                                            mailingaddress4lines,
                                            effective_date,
                                            expirationdate,
                                            licensetypecode,
                                            licensenumber,
                                            dup_count,
                                            licensegeocode,
                                            district,
                                            prem_address,
                                            owner,
                                            condi,
                                            runid,
                                            batchtype,
                                            issue_type,
                                            iss_type_details,
                                            color,
                                            serialnumber,
                                            jobid,
                                            othercount,
                                            dupdescriptor)
            SELECT UPPER(lt.licensetypename)
                       licensetypename,
                   UPPER(li.primarylicensee)
                       licensee,
                   NVL2(li.dba, 'DBA: ', '') || UPPER(li.dba)
                       lic_dba,
                   UPPER(lt.mailingaddress4lines)
                       mailingaddress4lines,
                   r.validfromdate
                       effective_date,
                   TRUNC(lt.expirationdate)
                       expirationdate,
                   TO_CHAR(lt.licensetypecode)
                       licensetypecode,
                   li.licensenumber,
                   NVL2(lt.masterlicensenumber,
                        1,
                        NVL(lt.primarycount, NULL))
                       dup_count,
                   lt.licensegeocode,
                   LPAD(TO_CHAR(lt.district), 2, 0)
                       district,
                   UPPER(
                       DECODE(lt.mailingaddress4lines,
                              lt.premisesaddress4lines, NULL,
                              lt.premisesaddress4lines))
                       prem_address,
                   li.licenseenames
                       owner,
                   TRIM(
                       ',' FROM TRIM(
                                    ' ' FROM    DECODE(lt.conda,
                                                       'Y', 'A',
                                                       NULL)
                                             || CHR(13)
                                             || DECODE(lt.condd,
                                                       'Y', 'D' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.condi,
                                                       'Y', 'I' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.condr,
                                                       'Y', 'R' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond1c,
                                                       'Y', '1C' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond7,
                                                       'Y', '7' || CHR(13),
                                                       NULL)
                                             || DECODE(
                                                    lt.cond2,
                                                    'Y',    '2'
                                                         || NVL2(
                                                                lt.conditionenddate,
                                                                   ' '
                                                                || lt.conditionenddate,
                                                                '')
                                                         || CHR(13),
                                                    NULL)
                                             || DECODE(
                                                    lt.cond5,
                                                    'Y',    '5'
                                                         || NVL2(
                                                                lt.conditionenddate,
                                                                   ' '
                                                                || lt.conditionenddate,
                                                                '')
                                                         || CHR(13),
                                                    NULL)
                                             || DECODE(lt.cond8,
                                                       'Y', '8' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond9,
                                                       'Y', '9' || CHR(13),
                                                       NULL)))
                       condi,
                   NULL
                       runid,
                   NULL
                       batchtype,
                   lt.typeofissuance
                       issue_type,
                   'ISSUE TYPE DETAILS'
                       iss_type_details,
                   p.color,
                   p.serialnumber
                       serialnumber,
                   li.jobid,
                   licenseecount
                       othercount,
                   NULL
                       dupdescriptor
              FROM query.p_producelicenses  p
                   JOIN query.r_producelicenseslicensetype r
                       ON r.producelicprocessid = p.processid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = r.licensetypejobid
                   JOIN query.r_licensetypeltcatprimary r2
                       ON r2.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory pltc
                       ON pltc.objectid = r2.licensetypecategoryobjectid
                   JOIN query.j_license li ON li.jobid = p.jobid
             WHERE p.processid = a_objectid
               AND pltc.color = p.color
               AND (r.printlicense = 'Y') --Added r.PrintLicense='Y' to only load data that if they want to print it
            UNION ALL
            SELECT UPPER(ltc.licensetypename)
                       licensetypename,
                   UPPER(li.primarylicensee)
                       licensee,
                   NVL2(li.dba, 'DBA: ', '') || UPPER(li.dba)
                       lic_dba,
                   UPPER(lt.mailingaddress4lines)
                       mailingaddress4lines,
                   CASE
                       WHEN TRUNC(do.readytoissuedate) >=
                            TRUNC(lt.expirationdate) THEN
                           ADD_MONTHS(pslt.validfromdate, 12)
                       ELSE
                           pslt.validfromdate
                   END
                       effective_date,
                   CASE
                       WHEN TRUNC(ltltcs.readytoissuedate) >=
                            TRUNC(lt.expirationdate) THEN
                           ADD_MONTHS(TRUNC(lt.expirationdate), 12)
                       ELSE
                           TRUNC(lt.expirationdate)
                   END
                       expirationdate,
                   TO_CHAR(ltc.licensetypecode)
                       licensetypecode,
                   li.licensenumber,
                   /*x.Column_Value*/
                   do.dupnumber
                       dup_count,
                   lt.licensegeocode,
                   LPAD(TO_CHAR(lt.district), 2, 0)
                       district,
                   UPPER(
                       DECODE(lt.mailingaddress4lines,
                              lt.premisesaddress4lines, NULL,
                              lt.premisesaddress4lines))
                       prem_address,
                   li.licenseenames
                       owner,
                   TRIM(
                       ',' FROM TRIM(
                                    ' ' FROM    DECODE(lt.conda,
                                                       'Y', 'A',
                                                       NULL)
                                             || CHR(13)
                                             || DECODE(lt.condd,
                                                       'Y', 'D' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.condi,
                                                       'Y', 'I' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.condr,
                                                       'Y', 'R' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond1c,
                                                       'Y', '1C' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond7,
                                                       'Y', '7' || CHR(13),
                                                       NULL)
                                             || DECODE(
                                                    lt.cond2,
                                                    'Y',    '2'
                                                         || NVL2(
                                                                lt.conditionenddate,
                                                                   ' '
                                                                || lt.conditionenddate,
                                                                '')
                                                         || CHR(13),
                                                    NULL)
                                             || DECODE(
                                                    lt.cond5,
                                                    'Y',    '5'
                                                         || NVL2(
                                                                lt.conditionenddate,
                                                                   ' '
                                                                || lt.conditionenddate,
                                                                '')
                                                         || CHR(13),
                                                    NULL)
                                             || DECODE(lt.cond8,
                                                       'Y', '8' || CHR(13),
                                                       NULL)
                                             || DECODE(lt.cond9,
                                                       'Y', '9' || CHR(13),
                                                       NULL)))
                       condi,
                   NULL
                       runid,
                   NULL
                       batchtype,
                   /*ltltcs.TypeofIssuance*/
                   do.typeofissuance
                       issue_type,
                   'ISSUE TYPE DETAILS'
                       iss_type_details,
                   p.color,
                   p.serialnumber
                       serialnumber,
                   li.jobid,
                   licenseecount
                       othercount,
                   do.description
                       dupdescriptor
              FROM query.p_producelicenses  p
                   JOIN query.j_license li ON li.jobid = p.jobid
                   JOIN query.r_licenselicensetype lilt
                       ON lilt.licensejobid = li.jobid
                   JOIN query.j_licensetype lt
                       ON lt.jobid = lilt.licensetypejobid
                   JOIN query.r_licensetypeltcatsecondary ltltcs
                       ON ltltcs.licensetypejobid = lt.jobid
                   JOIN query.o_licensetypecategory ltc
                       ON ltc.objectid = ltltcs.licensetypecategoryobjectid
                   JOIN query.r_producelicenseltcatsecondary pllts
                       ON pllts.producelicnesesprocessid = a_objectid
                   JOIN query.o_pendingsecondarylicensetype pslt
                       ON pslt.objectid = pllts.licensetypecategoryobjectid
                   JOIN query.r_pslttoltc psltltc
                       ON psltltc.pendingsecondaryltobjectid = pslt.objectid
                      AND psltltc.licensetypecategoryobjectid = ltc.objectid
                   JOIN sitespecific.duplicate_t dt
                       ON dt.relationshipid = ltltcs.relationshipid
                   JOIN query.o_duplicate do ON do.objectid = dt.duplicateid
             --cross join table(sitespecific.pkg_utils.GenerateRows(1,ltltcs.LicenseTypeCount)) x
             WHERE p.processid = a_objectid
               AND ltc.color = p.color
               AND (pslt.printlicense = 'Y');


        FOR c IN (  SELECT pgl.licensenumber,
                           pgl.licensee,
                           pgl.licensetypecode,
                           pgl.dup_count,
                           pgl.ROWID
                      FROM pinkandgreenlicense_fix pgl
                  ORDER BY 2,
                           1,
                           3,
                           4 NULLS FIRST)
        LOOP
            IF t_licensenumber != c.licensenumber THEN
                t_pagenumber   := 1;
            END IF;

            UPDATE pinkandgreenlicense_fix t
               SET t.pagenumber   = t_pagenumber
             WHERE t.ROWID = c.ROWID;

            t_pagenumber      := t_pagenumber + 1;
            t_licensenumber   := c.licensenumber;
        END LOOP;                                       --End Page Number Loop

        t_jobid   := api.pkg_columnquery.VALUE(a_objectid, 'JobId');

        FOR e
            IN (  SELECT LENGTH(le.formattedname)
                             namelength,
                         CEIL(LENGTH(le.formattedname) / g_ownerlinelength)
                             lines,
                         r.toobjectid
                             jobid
                    FROM api.relationships r
                         JOIN query.o_legalentity le
                             ON le.objectid = r.fromobjectid
                   WHERE r.toobjectid = t_jobid
                     AND (r.relationshipdefid =
                          api.pkg_configquery.objectdefidforname(
                              'r_LicenseP12LegalEntity')
                       OR r.relationshipdefid =
                          api.pkg_configquery.objectdefidforname(
                              'r_LicenseLegalEntityLicensee'))
                ORDER BY r.toobjectid, le.sortcolumn)
        LOOP
            t_nextjobid   := e.jobid;

            IF t_previousjobid IS NULL THEN
                t_previousjobid   := e.jobid;
                t_lines           := e.lines;
                t_counttemp       := 1;
                t_continue        := TRUE;
            ELSIF t_previousjobid != t_nextjobid THEN
                UPDATE pinkandgreenlicense_fix gt
                   SET gt.othercount   =
                           CASE
                               WHEN gt.othercount - t_counttemp > 0 THEN
                                   gt.othercount - t_counttemp
                               WHEN gt.othercount - t_counttemp <= 0 THEN
                                   0
                           END
                 WHERE gt.jobid = t_previousjobid;

                t_previousjobid   := e.jobid;
                t_lines           := e.lines;
                t_counttemp       := 1;
                t_continue        := TRUE;
            ELSIF t_previousjobid = t_nextjobid
              AND t_continue = TRUE THEN
                IF t_lines + e.lines <= 10 THEN
                    t_lines       := t_lines + e.lines;
                    t_counttemp   := t_counttemp + 1;
                ELSE
                    t_continue   := FALSE;
                END IF;
            END IF;
        END LOOP;                                       --End Other count Loop


        UPDATE pinkandgreenlicense_fix gt
           SET gt.othercount   =
                   CASE
                       WHEN gt.othercount - t_counttemp > 0 THEN
                           gt.othercount - t_counttemp
                       WHEN gt.othercount - t_counttemp <= 0 THEN
                           0
                   END
         WHERE gt.jobid = t_nextjobid;
    END;
END pkg_reprintlicenses;
/
