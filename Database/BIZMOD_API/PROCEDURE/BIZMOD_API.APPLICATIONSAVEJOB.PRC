CREATE OR REPLACE PROCEDURE BIZMOD_API.applicationsavejob(
    a_objectid     api.pkg_definition.udt_id,
    a_asofdate     DATE,
    a_jobid        api.pkg_definition.udt_id)
AS
    -- ****************************************************************************
    -- File:        BIZMOD_API.APPLICATIONSAVEJOB.PRC
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
    t_process      VARCHAR2(32) := 'APPLICATIONSAVEJOB';
    t_response     CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_status       VARCHAR2(40);
    t_outcome      VARCHAR2(40);
BEGIN
    t_applicationid := api.pkg_columnquery.VALUE(a_jobid, 'LSPId');

    t_outcome :=
        CASE
            WHEN a_objectid IS NULL
            THEN
                api.pkg_columnquery.VALUE(a_jobid, 'StatusName')
            ELSE
                api.pkg_columnquery.VALUE(a_objectid, 'Outcome')
        END;

    IF (t_outcome IS NOT NULL)
    THEN
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

    END IF;
END;
/
