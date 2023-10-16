CREATE OR REPLACE PROCEDURE BIZMOD_API.fileuploadjob(a_seq          NUMBER,
                                          a_asofdate     DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.FILEUPLOADJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose:
    --
    -- History:
    -------------------------------------------------------------------------------
    --              Date           Ticket         Comment
    --   1.0     09/19/2023  TJL  BIZ-12883    Initial process created
    -- ****************************************************************************
    t_doc          api.pkg_definition.udt_id;
    t_rel          api.pkg_definition.udt_id;
    t_data         BLOB;
    t_packet       CLOB;

    t_lsp_applicationid VARCHAR2(100);
    t_abisid       NUMBER;
    t_basefilename VARCHAR2(256);
    t_extension    VARCHAR2(32);
    t_description  VARCHAR2(256);
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
BEGIN
    SELECT e.packet, e.filedata
      INTO t_packet, t_data
      FROM bizmod_api.eservices_log_t e
     WHERE e.seq = a_seq;

    SELECT lsp_applicationid,
           abisprocessid,
           basefilename,
           extension,
           description
      INTO t_lsp_applicationid,
           t_abisid,
           t_basefilename,
           t_extension,
           t_description
      FROM JSON_TABLE(
               t_packet,
               '$'
               COLUMNS(
                   packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                   NESTED PATH '$.DATA[*]'
                       COLUMNS(
                           lsp_applicationid VARCHAR2(100)
                               PATH '$.LSPAPPLICATIONID',
                           abisprocessid NUMBER PATH '$.ABISPROCESSID',
                           basefilename VARCHAR2(256) PATH '$.BASEFILENAME',
                           extension VARCHAR2(32) PATH '$.EXTENSION',
                           description VARCHAR2(256) PATH '$.DESCRIPTION')));

    IF (t_abisid IS NULL)
    THEN
        t_abisid :=
            api.pkg_simplesearch.objectbyindex('p_IssueCatererEventAuth',
                                               'LSPId',
                                               t_lsp_applicationid);

        IF (t_abisid IS NULL)
        THEN
            RAISE NO_DATA_FOUND;
        END IF;
    END IF;

    t_doc :=
        api.pkg_documentupdate.new(
            a_documenttypeid => 321008,
            a_data      => t_data,
            a_uncompressedlength => DBMS_LOB.getlength(t_data),
            a_basename  => t_basefilename,
            a_extension => t_extension);

    api.pkg_columnupdate.setvalue(t_doc, 'Description', t_description);
    api.pkg_columnupdate.setvalue(t_doc,
                                  'FileName',
                                  t_basefilename || '.' || t_extension);

    t_rel :=
        api.pkg_relationshipupdate.new(
            a_endpoint  =>
                api.pkg_configquery.endpointidforname(
                    api.pkg_columnquery.VALUE(t_abisid, 'ObjectDefName'),
                    'Document'),
            a_fromobject => t_abisid,
            a_toobject  => t_doc);

    INSERT INTO bizmod_api.e_process_log_t(seq, processjob, info)
             VALUES (
                 a_seq,
                 'FILEUPLOADJOB',
                 'LSP Id: '
                 || t_lsp_applicationid
                 || CHR(13)
                 || 'Catering Id: '
                 || t_abisid
                 || CHR(13)
                 || 'File: '
                 || t_basefilename
                 || '.'
                 || t_extension);
EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;

        api.pkg_logicaltransactionupdate.resettransaction;
        ROLLBACK;


        INSERT INTO bizmod_api.e_process_log_t(seq,
                                               processjob,
                                               info,
                                               errmsg,
                                               bktrace)
             VALUES (a_seq,
                     'FILEUPLOADJOB',
                     NULL,
                     t_sqlerrm,
                     t_trace);

        COMMIT;

        RAISE;
END;
/


GRANT EXECUTE ON BIZMOD_API.FILEUPLOADJOB TO POSSEEXTENSIONS;
