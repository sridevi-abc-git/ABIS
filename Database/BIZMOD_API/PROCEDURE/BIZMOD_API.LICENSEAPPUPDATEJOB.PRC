CREATE OR REPLACE PROCEDURE BIZMOD_API.licenseappupdatejob
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.LICENSEAPPUPDATEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --   1.0.0   01/28/2026  TJL BIZ-19069  Initial Procedure Created
    -- **************************************************************************

    TYPE proc_rec
        IS RECORD(applicationid bizmod_api.license_app_t.lspid%TYPE,
                  licensenumber bizmod_api.license_app_t.licensenumber%TYPE,
                  jobid bizmod_api.license_app_t.jobid%TYPE,
                  errmsg VARCHAR2(4000));

    TYPE proc_tbl IS TABLE OF proc_rec;

    t_proc_info    proc_tbl := proc_tbl();

    t_url CONSTANT VARCHAR2(1000)
        := '/api/licensing/internal/license-applications/<<ApplicationId>>/appUpdate' ;
    t_method CONSTANT VARCHAR2(10) := 'PATCH';
    t_process      VARCHAR2(32) := 'LICENSEAPPUPDATEJOB';
    t_header       VARCHAR2(32000) := CHR(13);
    t_license_data CLOB;
    t_applicationid VARCHAR2(1000);
    t_results      json_object_t := json_object_t();
    t_urlinfo      VARCHAR2(10000);
    t_results_text VARCHAR2(32767);

    t_abis         json_object_t;
    t_curr         json_object_t;
    t_new          json_object_t := json_object_t();
    t_abis_tmp     json_element_t;
    t_premise      json_object_t := json_object_t();
    t_add          BOOLEAN := FALSE;
    t_sqlerrm      VARCHAR2(32000);
BEGIN
    FOR rec IN (SELECT a.jobid,
                       a.licensedata,
                       a.lspid,
                       a.licensenumber
                  FROM bizmod_api.license_app_t a
                 WHERE a.statusname IN ('PEND', 'POSTED')
                   AND a.licensedata IS NOT NULL
                   AND ROWNUM < 2)
    LOOP
        -- get current application data
        t_license_data :=
            bizmod_api.pkg_abis.get_license_data(a_jobid => rec.jobid);

        DBMS_OUTPUT.put_line(rec.jobid);

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

        t_abis_tmp := t_abis.get_object('applicants');

        IF (t_abis_tmp.TO_CLOB != t_curr.get_object('applicants').TO_CLOB)
        THEN
            t_new.put('applicants', t_abis_tmp);
        END IF;

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
        t_urlinfo := REPLACE(t_url, '<<applicationId>>', t_applicationid);

        t_results :=
            bizmod_api.utl_licenseinfo.notify_lsp(a_urlinfo   => t_urlinfo,
                                                  a_method    => t_method,
                                                  a_content   => t_new);

        t_results_text := t_results.TO_CLOB;
        DBMS_OUTPUT.put_line(t_results_text);

        IF (t_results.get_number('status') != 200)
        THEN
            t_proc_info(t_proc_info.COUNT).errmsg :=
                CASE
                    WHEN t_results.get_type('lspresponse') = 'ARRAY'
                    THEN
                        t_results.get_array('lspresponse').TO_CLOB
                    WHEN t_results.get_type('lspresponse') = 'OBJECT'
                    THEN
                        t_results.get_object('lspresponse').TO_CLOB
                    WHEN t_results.get_type('lspresponse') = 'SCALAR'
                    THEN
                        t_results.get_clob('lspresponse')
                    WHEN t_results.get_type('ora-error') = 'SCALAR'
                    THEN
                        t_results.get_clob('ora-error')
                    ELSE
                        t_results.TO_CLOB
                END;
        --                SUBSTR(t_results.get_clob('lspresponse'), 1, 4000);
        --        ELSE
        --            UPDATE bizmod_api.license_app_t a
        --               SET a.licensedata = t_license_data
        --             WHERE a.jobid = rec.jobid;
        --
        --            COMMIT;
        END IF;
    --        DBMS_OUTPUT.put_line(
    --            json_query(t_new.TO_CLOB, '$' RETURNING CLOB PRETTY));
    END LOOP;

    -- log job information
    IF (t_proc_info.COUNT > 0)
    THEN
        FOR i IN 1 .. t_proc_info.COUNT
        LOOP
            t_header :=
                t_header
                || LPAD(t_proc_info(i).applicationid, 9, ' ')
                || CHR(9)
                || t_proc_info(i).licensenumber
                || CHR(9)
                || t_proc_info(i).jobid
                || CHR(9)
                || SUBSTR(REGEXP_SUBSTR(t_proc_info(i).errmsg,
                                        '^[^' || CHR(10) || CHR(13) || ']*',
                                        1,
                                        1,
                                        'm'),
                          1,
                          200)
                || CHR(13);

            IF (t_proc_info(i).errmsg IS NOT NULL)
            THEN
                t_sqlerrm :=
                    t_sqlerrm
                    || LPAD(t_proc_info(i).applicationid, 12, ' ')
                    || CHR(9)
                    || t_proc_info(i).licensenumber
                    || CHR(9)
                    || t_proc_info(i).jobid
                    || CHR(9)
                    || SUBSTR(t_proc_info(i).errmsg, 1, 200)
                    || CHR(13);
            END IF;

            EXIT WHEN LENGTH(t_header) > 4000;
        END LOOP;

        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg)
             VALUES (0,
                     t_process,
                     SUBSTR(t_header, 1, 4000),
                     SUBSTR(t_sqlerrm, 1, 4000));

        COMMIT;
    END IF;
END licenseappupdatejob;
/
