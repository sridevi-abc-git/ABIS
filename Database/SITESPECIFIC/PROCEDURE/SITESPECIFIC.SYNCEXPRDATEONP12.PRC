CREATE OR REPLACE PROCEDURE SITESPECIFIC.syncexprdateonp12(
    a_jobid         api.pkg_definition.udt_id,
    a_asofdate      DATE,
    a_expiringmonth VARCHAR2,
    a_expiringyear  INTEGER)
AS
    -- **************************************************************************
    -- File:        SYNCEXPRDATEONP12.PRC
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

    t_isp12master          CHAR;
    t_p12masterlicenseno   api.pkg_definition.udt_id;
BEGIN
    t_isp12master   :=
        api.pkg_columnquery.VALUE(a_jobid, 'ThisLicenseIsP12Master');
    t_p12masterlicenseno   :=
        api.pkg_columnquery.numericvalue(a_jobid, 'P12MasterLicenseNo');

    IF (t_isp12master = 'Y')
    OR (t_p12masterlicenseno IS NOT NULL) THEN
        FOR c IN (SELECT licensetypejobid
                    FROM query.r_licenselicensetype
                   WHERE licensejobid = a_jobid)
        LOOP
            IF (api.pkg_columnquery.numericvalue(c.licensetypejobid,
                                                 'SeasonStartMonthNumber')
                    IS NULL) THEN
                api.pkg_columnupdate.setvalue(c.licensetypejobid,
                                              'ExpiringMonth',
                                              a_expiringmonth);
                api.pkg_columnupdate.setvalue(c.licensetypejobid,
                                              'ExpiringYear',
                                              a_expiringyear);
            END IF;
        END LOOP;
    ELSE
        dbms_output.put_line('Is not P12 Master'); -- set user error using api.error...... as this is not a P12 type license
    END IF;
END syncexprdateonp12;
/
