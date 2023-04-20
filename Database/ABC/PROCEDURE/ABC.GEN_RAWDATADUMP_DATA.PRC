CREATE OR REPLACE PROCEDURE ABC.gen_rawdatadump_data
AS
    -- **************************************************************************
    -- File:        GEN_RAWDATADUMP_DATA.PRC
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

    v_rec_count          INTEGER;
    v_lt_count           INTEGER;
    v_jobid              abc.rawdatadump_t.jobid%TYPE;

    v_type_type          abc.rawdatadump_t.type_type%TYPE;
    v_type_status        abc.rawdatadump_t.type_status%TYPE;
    v_type_master_ind    abc.rawdatadump_t.type_master_ind%TYPE;
    v_type_status_date   abc.rawdatadump_t.type_status_date%TYPE;
    v_type_orig_iss      abc.rawdatadump_t.type_orig_iss%TYPE;
    v_type_next_issue    abc.rawdatadump_t.type_next_issue%TYPE;
    v_type_dup_count     abc.rawdatadump_t.type_dup_count%TYPE;
    v_type_fee_code      abc.rawdatadump_t.type_fee_code%TYPE;
    v_type_term          abc.rawdatadump_t.type_term%TYPE;
    v_type_trf_from      abc.rawdatadump_t.type_trf_from%TYPE;

    CURSOR c_license
    IS
        SELECT '1'
                   source,
               l.jobid,
               l.licensenumber,
               l.statusname,
               jsc.effectivestartdate
                   statusdate,
               l.premaddressgeocode
                   geocode,
               TO_CHAR(l.basefileofficecodecorral)
                   dist,
               l.primarylicensee
                   licensee,
               ad2.addressline1
                   premaddr1,
               ad2.addressline2
                   premaddr2,
               ad2.usacity
                   premcity,
               ad2.usastatecode
                   premstate,
               ad2.zipcode
                   premzip,
               TO_CHAR(l.premaddresscensustract)
                   census,
               l.primarydba,
               ad1.addressline1
                   mailaddr1,
               CASE
                   WHEN UPPER(ad1.addresslocation) = 'OUTSIDE USA' THEN
                          ad1.addressline2
                       || ', '
                       || NVL2(ad1.addressline3,
                               ad1.addressline3 || ', ',
                               '')
                       || ad1.country
                   ELSE
                       ad1.addressline2
               END
                   mailaddr2,
               ad1.usacity
                   mailcity,
               ad1.usastatecode
                   mailstate,
               ad1.zipcode
                   mailzip
          FROM query.j_license  l
               JOIN api.jobstatuses js
                   ON js.jobtypeid = l.jobtypeid
                  AND js.statusid = l.statusid
                  AND js.statustype = 'O'
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = l.jobid
                  AND jsc.mostrecent = 'Y'
               LEFT OUTER JOIN query.r_licenseaddrmailing rma
                   ON rma.licensejobid = l.jobid
               LEFT OUTER JOIN query.o_address ad1
                   ON ad1.objectid = rma.maobjectid
               LEFT OUTER JOIN query.r_licenseaddrpremises rpa
                   ON rpa.licensejobid = l.jobid
               LEFT OUTER JOIN query.o_address ad2
                   ON ad2.objectid = rpa.premisesobjectid
        UNION
        SELECT '2'
                   source,
               a.jobid,
               a.licensenumber,
               a.statusname,
               jsc.effectivestartdate
                   statusdate,
               a.premgeocode
                   geocode,
               TO_CHAR(a.basefileofficecodecorral)
                   dist,
               a.primarylicensee
                   licensee,
               ad1.addressline1
                   premaddr1,
               ad1.addressline2
                   premaddr2,
               ad1.usacity
                   premcity,
               ad1.usastatecode
                   premstate,
               ad1.zipcode
                   premzip,
               TO_CHAR(a.premcensustract)
                   census,
               a.primarydba,
               ad2.addressline1
                   mailaddr1,
               CASE
                   WHEN UPPER(ad2.addresslocation) = 'OUTSIDE USA' THEN
                          ad2.addressline2
                       || ', '
                       || NVL2(ad2.addressline3,
                               ad2.addressline3 || ', ',
                               '')
                       || ad2.country
                   ELSE
                       ad2.addressline2
               END
                   mailaddr2,
               ad2.usacity
                   mailcity,
               ad2.usastatecode
                   mailstate,
               ad2.zipcode
                   mailzip
          FROM query.j_application  a
               JOIN api.jobstatuses js
                   ON js.jobtypeid = a.jobtypeid
                  AND js.statusid = a.statusid
                  AND js.statustype = 'O'
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = a.jobid
                  AND jsc.mostrecent = 'Y'
               LEFT OUTER JOIN query.r_applicationpremaddr rpa
                   ON rpa.applicationjobid = a.jobid
               LEFT OUTER JOIN query.o_address ad1
                   ON ad1.objectid = rpa.addressobjectid
               LEFT OUTER JOIN query.r_applicationmailaddr rma
                   ON rma.applicationjobid = a.jobid
               LEFT OUTER JOIN query.o_address ad2
                   ON ad2.objectid = rma.addressobjectid
        ORDER BY licensenumber, source;

    c_license_rec        c_license%ROWTYPE;

    CURSOR c_lictype
    IS
        /* Primary License Type */
        SELECT rlt.licensejobid
                   licensejobid,
               '1'
                   source,
               RPAD(lt.licensetypecode, 4, ' ')
                   ltcode,
               RPAD(lt.statusname, 8, ' ')
                   ltstatus,
               RPAD(lt.hassecondary, 1, ' ')
                   ltmi,
               RPAD(NVL(TO_CHAR(jsc.effectivestartdate, 'DD-MON-YY'), ''),
                    9,
                    ' ')
                   ltstatusdate,
               RPAD(TO_CHAR(lt.issuedate, 'DD-MON-YY'), 9, ' ')
                   ltissuedate,
               RPAD(lt.renewaldate, 9, ' ')
                   ltrenewaldate,
               LPAD(lt.secondarylicensetypecount, 3, '0')
                   lt2typecount,
               RPAD(lt.feeschedulecode, 10, ' ')
                   ltfeecode,
               RPAD(
                      NVL(lt.licensetypecode, '  ')
                   || '-'
                   || NVL(lt.licensenumber, ' '),
                   11,
                   ' ')
                   lictypelicnum
          FROM query.j_licensetype  lt
               JOIN query.r_licenselicensetype rlt
                   ON rlt.licensetypejobid = lt.jobid
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = lt.jobid
                  AND jsc.mostrecent = 'Y'
               JOIN api.jobstatuses js
                   ON js.jobtypeid = lt.jobtypeid
                  AND js.statusid = lt.statusid
                  AND js.statustype IN ('O', 'I')
         WHERE rlt.licensejobid = v_jobid
        /*   For Testing
         WHERE rlt.licensejobid in
               (select L.JOBID
                  FROM QUERY.j_license l
                  JOIN api.jobstatuses js on js.jobtypeid = l.jobtypeid and js.statusid = l.statusid and js.statustype = 'O'
                  LEFT outer join extension.jobstatuschange_t jsc on jsc.jobid = l.jobid and jsc.mostrecent = 'Y'
                Union
                select A.JOBID
                  FROM QUERY.j_application a
                  JOIN api.jobstatuses js on js.jobtypeid = a.jobtypeid and js.statusid = a.statusid and js.statustype = 'O'
                  LEFT outer join extension.jobstatuschange_t jsc on jsc.jobid = a.jobid and jsc.mostrecent = 'Y')
        */
        UNION
        /* Secondary License Type */
        SELECT rlt.licensejobid
                   licensejobid,
               '2'
                   source,
               RPAD(oltc.licensetypecode, 4, ' ')
                   ltcode,
               RPAD(NVL(slt.status, lt.statusname), 8, ' ')
                   ltstatus,
               --       RPAD (slt.status, 8, ' ') ltstatus,
               RPAD('N', 1, ' ')
                   ltmi,
               RPAD(
                   TO_CHAR(NVL(slt.statusdate, jsc.effectivestartdate),
                           'DD-MON-YY'),
                   9,
                   ' ')
                   ltstatusdate,
               --       RPAD(to_char(SLT.STATUSDATE,'DD-MON-YY'),9,' ') LTStatusDate,
               RPAD(TO_CHAR(lt.issuedate, 'DD-MON-YY'), 9, ' ')
                   ltissuedate,
               RPAD(lt.renewaldate, 9, ' ')
                   ltrenewaldate,
               LPAD(0, 3, '0')
                   lt2typecount,
               RPAD(lt.feeschedulecode, 10, ' ')
                   ltfeecode,
               RPAD(
                      NVL(oltc.licensetypecode, '  ')
                   || '-'
                   || NVL(lt.licensenumber, ' '),
                   11,
                   ' ')
                   lictypelicnum
          FROM query.r_licenselicensetype  rlt
               JOIN query.j_licensetype lt ON lt.jobid = rlt.licensetypejobid
               JOIN query.r_licensetypeltcatsecondary slt
                   ON slt.licensetypejobid = lt.jobid
               JOIN query.o_licensetypecategory oltc
                   ON oltc.objectid = slt.licensetypecategoryobjectid
               JOIN api.jobstatuses js
                   ON js.jobtypeid = lt.jobtypeid
                  AND js.statusid = lt.statusid
                  AND js.statustype IN ('O', 'I')
               LEFT OUTER JOIN extension.jobstatuschange_t jsc
                   ON jsc.jobid = lt.jobid
                  AND jsc.mostrecent = 'Y'
         WHERE rlt.licensejobid = v_jobid
        /*   For Testing
         WHERE rlt.licensejobid in
               (select L.JOBID
                  FROM QUERY.j_license l
                  JOIN api.jobstatuses js on js.jobtypeid = l.jobtypeid and js.statusid = l.statusid and js.statustype = 'O'
                  LEFT outer join extension.jobstatuschange_t jsc on jsc.jobid = l.jobid and jsc.mostrecent = 'Y'
                Union
                select A.JOBID
                  FROM QUERY.j_application a
                  JOIN api.jobstatuses js on js.jobtypeid = a.jobtypeid and js.statusid = a.statusid and js.statustype = 'O'
                  LEFT outer join extension.jobstatuschange_t jsc on jsc.jobid = a.jobid and jsc.mostrecent = 'Y')
        */
        ORDER BY source, ltcode;

    c_lictype_rec        c_lictype%ROWTYPE;
BEGIN
    --delete abc.rawdatadump_t;  --johnny's original code
    DELETE FROM abc.rawdatadump_t;

    COMMIT;

    v_rec_count   := 0;

    OPEN c_license;

    LOOP
        FETCH c_license INTO c_license_rec;

        EXIT WHEN c_license%NOTFOUND;

        v_rec_count   := v_rec_count + 1;
        v_jobid       := c_license_rec.jobid;

        BEGIN
            v_lt_count           := 0;
            v_type_type          := '';
            v_type_status        := '';
            v_type_master_ind    := '';
            v_type_status_date   := '';
            v_type_orig_iss      := '';
            v_type_next_issue    := '';
            v_type_dup_count     := '';
            v_type_fee_code      := '';
            v_type_trf_from      := '';

            OPEN c_lictype;

            LOOP
                FETCH c_lictype INTO c_lictype_rec;

                EXIT WHEN c_lictype%NOTFOUND;

                v_type_type          := v_type_type || c_lictype_rec.ltcode;
                v_type_status        := v_type_status || c_lictype_rec.ltstatus;
                v_type_master_ind    :=
                    v_type_master_ind || c_lictype_rec.ltmi;
                v_type_status_date   :=
                    v_type_status_date || c_lictype_rec.ltstatusdate;
                v_type_orig_iss      :=
                    v_type_orig_iss || c_lictype_rec.ltissuedate;
                v_type_next_issue    :=
                    v_type_next_issue || c_lictype_rec.ltrenewaldate;
                v_type_dup_count     :=
                    v_type_dup_count || c_lictype_rec.lt2typecount;
                v_type_fee_code      :=
                    v_type_fee_code || c_lictype_rec.ltfeecode;
                v_type_trf_from      :=
                    v_type_trf_from || c_lictype_rec.lictypelicnum;

                v_lt_count           := v_lt_count + 1;

                IF v_lt_count > 9 THEN
                    EXIT;
                END IF;
            END LOOP;

            CLOSE c_lictype;
        END;

        INSERT INTO abc.rawdatadump_t(jobid,
                                      licensenumber,
                                      status,
                                      statusdate,
                                      geocode,
                                      dist,
                                      type_type,
                                      type_status,
                                      type_master_ind,
                                      type_status_date,
                                      type_orig_iss,
                                      type_next_issue,
                                      type_dup_count,
                                      type_fee_code,
                                      type_term,
                                      type_trf_from,
                                      primarylicensee,
                                      premaddrline1,
                                      premaddrline2,
                                      premaddrcity,
                                      premaddrstatecode,
                                      premaddrzipcode,
                                      premaddrcensus,
                                      primarydba,
                                      mailaddrline1,
                                      mailaddrline2,
                                      mailaddrcity,
                                      mailaddrstatecode,
                                      mailaddrzipcode)
             VALUES (c_license_rec.jobid,
                     c_license_rec.licensenumber,
                     c_license_rec.statusname,
                     c_license_rec.statusdate,
                     c_license_rec.geocode,
                     c_license_rec.dist,
                     v_type_type,
                     v_type_status,
                     v_type_master_ind,
                     v_type_status_date,
                     v_type_orig_iss,
                     v_type_next_issue,
                     v_type_dup_count,
                     v_type_fee_code,
                     v_type_term,
                     v_type_trf_from,
                     c_license_rec.licensee,
                     c_license_rec.premaddr1,
                     c_license_rec.premaddr2,
                     c_license_rec.premcity,
                     c_license_rec.premstate,
                     c_license_rec.premzip,
                     c_license_rec.census,
                     c_license_rec.primarydba,
                     c_license_rec.mailaddr1,
                     c_license_rec.mailaddr2,
                     c_license_rec.mailcity,
                     c_license_rec.mailstate,
                     c_license_rec.mailzip);

        IF v_rec_count >= 100 THEN
            COMMIT;
            v_rec_count   := 0;
        END IF;
    END LOOP;

    CLOSE c_license;
END gen_rawdatadump_data;
/


GRANT EXECUTE ON ABC.GEN_RAWDATADUMP_DATA TO POSSEEXTENSIONS;
