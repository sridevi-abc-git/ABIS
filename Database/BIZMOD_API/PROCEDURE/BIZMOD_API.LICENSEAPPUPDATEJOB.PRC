CREATE OR REPLACE PROCEDURE BIZMOD_API.licenseappupdatejob
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.LICENSEAPPUPDATEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --   1.0.1   01/28/2026  TJL BIZ-19069  Initial Procedure Created
    --   2.0.0   03/09/2026  TJL BIZ-20163  Change URL endpoint process is calling
    -- **************************************************************************


    TYPE proc_rec
        IS RECORD(applicationid bizmod_api.license_app_t.lspid%TYPE,
                  licensenumber bizmod_api.license_app_t.licensenumber%TYPE,
                  jobid bizmod_api.license_app_t.jobid%TYPE,
                  errmsg VARCHAR2(4000));

    TYPE proc_tbl IS TABLE OF proc_rec;

    t_proc_info    proc_tbl := proc_tbl();

    t_url CONSTANT VARCHAR2(1000)
        := '/api/licensing/internal/license-applications/<<applicationid>>' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_process      VARCHAR2(32) := 'LICENSEAPPUPDATEJOB';
    t_license_data CLOB;
    t_results      json_object_t := json_object_t();
    t_urlinfo      VARCHAR2(10000);
    t_results_text VARCHAR2(32767);

    t_abis         json_object_t;
    t_curr         json_object_t;
    t_new          json_object_t := json_object_t();
    t_new_clob     CLOB;
    t_abis_tmp     json_element_t;
    t_premise      json_object_t := json_object_t();
    t_add          BOOLEAN := FALSE;
    t_seq          NUMBER;
    t_errid        NUMBER;
    t_status_code  NUMBER;
BEGIN
    FOR rec IN (SELECT a.jobid,
                       a.licensedata,
                       a.lspid,
                       a.licensenumber
                  FROM bizmod_api.license_app_t a
                 WHERE a.statusname IN ('PEND', 'POSTED')
                   AND a.licensedata IS NOT NULL)
    LOOP
        -- get current application data
        t_license_data :=
            bizmod_api.pkg_abis.get_license_data(a_jobid => rec.jobid);

        -- compare hash value to see if data has been changed in abis
        CONTINUE WHEN rec.licensedata = t_license_data;

        -- add info to process table
        t_proc_info.EXTEND(1);
        t_proc_info(t_proc_info.COUNT) :=
            proc_rec(rec.lspid,
                     rec.licensenumber,
                     rec.jobid,
                     NULL);

        -- find out which sections changed
        t_new.put('objectId', rec.jobid);

        t_abis := json_object_t.parse(t_license_data);
        t_curr := json_object_t.parse(rec.licensedata);

        -- **********************************************************
        -- check for applicant chages, position holder
        -- **********************************************************

        t_abis_tmp := t_abis.get_object('premises').get_object('newAddress');

        IF (t_abis_tmp.TO_CLOB !=
            t_curr.get_object('premises').get_object('newAddress').TO_CLOB)
        THEN
            t_premise.put('newAddress', t_abis_tmp);
            t_add := TRUE;
        END IF;

        IF (t_abis.get_object('premises').get_string('newDBAName') !=
            t_curr.get_object('premises').get_string('newDBAName'))
        THEN
            t_premise.put(
                'newDBAName',
                t_abis.get_object('premises').get_string('newDBAName'));
            t_add := TRUE;
        END IF;

        IF (t_add)
        THEN
            t_new.put('premises', t_premise);
        END IF;

        t_abis_tmp := t_abis.get('primaryLicenseTypes');

        IF (t_abis_tmp.TO_CLOB != t_curr.get('primaryLicenseTypes').TO_CLOB)
        THEN
            t_new.put('primaryLicenseTypes', t_abis_tmp);
        END IF;

        -- send LSP application change values
        t_urlinfo := REPLACE(t_url, '<<applicationid>>', rec.lspid);

        t_results :=
            bizmod_api.utl_licenseinfo.notify_lsp(a_urlinfo   => t_urlinfo,
                                                  a_method    => t_method,
                                                  a_content   => t_new);

        t_new_clob := t_new.TO_CLOB;
        t_results_text := t_results.TO_CLOB;

        t_seq := NVL(t_results.get_number('seq'), 0);
        t_errid := t_results.get_number('errid');
        t_status_code := t_results.get_number('status_code');

        IF (t_status_code != 200
            and t_status_code > 0)
        THEN
            INSERT INTO bizmod_api.e_errors_t e(e.licensenumber,
                                                e.objectid,
                                                e.applicationid,
                                                e.process,
                                                e.errcode,
                                                e.errm)
                 VALUES (rec.licensenumber,
                         rec.jobid,
                         rec.lspid,
                         t_process,
                         t_status_code,
                         t_results.get_clob('lspresponse'))
              RETURNING errid
                   INTO t_errid;
        END IF;

        INSERT INTO bizmod_api.e_process_log_t pl(pl.seq,
                                                  pl.licensenumber,
                                                  pl.objectid,
                                                  pl.applicationid,
                                                  pl.processjob,
                                                  pl.errid,
                                                  pl.packet)
             VALUES (t_seq,
                     rec.licensenumber,
                     rec.jobid,
                     rec.lspid,
                     t_process,
                     t_errid,
                     t_new_clob);

        COMMIT;

        UPDATE bizmod_api.license_app_t a
           SET a.licensedata = t_license_data
         WHERE a.jobid = rec.jobid;

        COMMIT;
    END LOOP;

END licenseappupdatejob;
/


GRANT EXECUTE ON BIZMOD_API.LICENSEAPPUPDATEJOB TO POSSEEXTENSIONS;
