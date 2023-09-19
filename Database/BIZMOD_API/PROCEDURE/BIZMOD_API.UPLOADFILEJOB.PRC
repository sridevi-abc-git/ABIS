CREATE OR REPLACE PROCEDURE BIZMOD_API.uploadfilejob(a_seq NUMBER, a_asofdate DATE)
IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.UPLOADFILEJOB.PRC
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

    t_lsp_applicationid VARCHAR2(100);
    t_abissid      NUMBER;
    t_basefilename VARCHAR2(256);
    t_extension    VARCHAR2(32);
    t_description  VARCHAR2(256);
BEGIN
    SELECT e.filedata
      INTO t_data
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
               a_packet,
               '$'
               COLUMNS(
                   packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                   NESTED PATH '$.DATA[*]'
                       COLUMNS(lsp_applicationid VARCHAR2(100) PATH '$.',
                               abisprocessid NUMBER PATH '$.',
                               basefilename VARCHAR2(256) PATH '$.',
                               extension VARCHAR2(32) PATH '$.',
                               description VARCHAR2(256) PATH '$.')));



    t_doc :=
        api.pkg_documentupdate.new(
            a_documenttypeid => 321008,
            a_data      => t_filedata,
            a_uncompressedlength => DBMS_LOB.getlength(t_filedata),
            a_basename  => t_basename,
            a_extension => t_extension);


    t_rel :=
        api.pkg_relationshipupdate.new(a_endpoint  => udt_id,
                                       a_fromobject => t_abisid,
                                       a_toobject  => t_doc);
END;
/
