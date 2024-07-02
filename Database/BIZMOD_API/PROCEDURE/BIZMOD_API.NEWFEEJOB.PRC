CREATE OR REPLACE PROCEDURE BIZMOD_API.newfeejob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.NEWFEEJOB.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --          Date           Ticket     Comment
    --   1.0  07/01/2024 TJL  BIZ-15444  Initial Procedure Created
    -- ****************************************************************************
    t_parameternames json_object_t;
    t_replacementvalues json_object_t;
    t_applicationid NUMBER;
    t_status        varchar2(50);
    t_process      VARCHAR2(32) := 'NEWFEEJOB';
    t_response     CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
BEGIN
    t_applicationid := api.pkg_columnquery.VALUE(a_objectid, 'LSPId');
    -- update LSP of any changes to application data
    t_parameternames :=
        json_object_t('{"URL":"URL_STATUS","METHOD":"METHOD"}');
    t_replacementvalues :=
        json_object_t(
            '{"<<applicationId>>":"'
            || t_applicationid
            || '","<<status>>":"'
            || t_status
            || '"}');

    t_response :=
        bizmod_api.utl_licenseinfo.calllsp(
            a_process   => t_process,
            a_parameternames => t_parameternames,
            a_replacementvalues => t_replacementvalues);
---- do something with t_response

END;
/


GRANT EXECUTE ON BIZMOD_API.NEWFEEJOB TO POSSEDBA;
