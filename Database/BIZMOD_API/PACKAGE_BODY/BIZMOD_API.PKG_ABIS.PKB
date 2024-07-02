CREATE OR REPLACE PACKAGE BODY BIZMOD_API.pkg_abis
AS
    -- **************************************************************************
    -- File:        BIZMOD_API.PKG_ABIS.PKB
    -- Author:      Timothy J. Lord
    --
    -- History:
    -----------------------------------------------------------------------------
    --    Ver:     Date                       Comment
    --     1.0   07/01/2024  TJL BIZ-15444  Move and renamed package from
    --                                        SITESPECIFIC.PKG_CATERING and added
    --                                        new procedures and functions to support
    --                                        License Applications
    -- **************************************************************************
    PROCEDURE cateringnotifylsp(a_objectid     api.pkg_definition.udt_id,
                                a_asofdate     DATE)
    IS
        a_scheduleddate DATE := SYSDATE;
        t_cnt          NUMBER := 0;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    BEGIN
        -- check if online application
        IF (api.pkg_columnquery.VALUE(a_objectid, 'LSPId') IS NOT NULL)
        THEN
            a_scheduleddate :=
                CASE api.pkg_columnquery.VALUE(a_objectid, 'OutCome')
                    WHEN 'Approved' THEN -- add 2 minute delay to when job is to run to allow abc-218 to be generated
                                         SYSDATE + ((1 / 24 / 60) * 2)
                    ELSE SYSDATE
                END;

            -- check to see if this application has already been secheuled. This process can be called twice
            --  when application is approved
            SELECT COUNT(s.object)
              INTO t_cnt
              FROM scheduler.sysschedule s
             WHERE s.description =
                   'E-Services Catering Notify LSP Job ' || a_objectid
               AND TRUNC(s.scheduledate) >= TRUNC(SYSDATE)
               AND status IN (1, 3);

            IF (t_cnt = 0)
            THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'CATERINGNOTIFYLSPJOB',
                    a_description =>
                        'E-Services Catering Notify LSP Job ' || a_objectid,
                    a_argument1 => a_objectid,
                    a_argument2 => a_scheduleddate);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                 VALUES (0,
                         'CATERINGNOTIFYLSP',
                         'Application Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    END;


    PROCEDURE newfee(a_objectid     IN api.pkg_definition.udt_id,
                     a_asofdate        DATE)
    IS
        t_cnt          NUMBER := 0;
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
        t_pending      VARCHAR2(1);
        
    BEGIN
        IF (api.pkg_columnquery.VALUE(a_objectid, 'LSPId') IS NOT NULL)
        THEN
            begin
            -- check to see if job is already scheduled
            select pending
              into t_pending
              from bizmod_api.license_app_t 
             where jobid = a_objectid
               and nvl(pending, 'N') = 'Y';
            
            exception when no_data_found then
                -- schedule job to notify LSP of new fees avaible to be paid
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'NEWFEEJOB',
                    a_description =>
                        'E-Services New Fee Notify LSP Job ' || a_objectid,
                    a_argument1 => a_objectid,
                    a_argument2 => SYSDATE + (1 / (24 * 60)) * 5); -- 5 minute delay
                    
                update bizmod_api.license_app_t
                   set pending = 'Y'
                 where jobid = a_objectid;
            end;
        END IF;
        
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                 VALUES (0,
                         'NEWFEE',
                         'Application Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    END;
    
    PROCEDURE applicationsave(a_objectid     IN api.pkg_definition.udt_id,
                              a_asofdate     IN DATE,
                              a_jobid        IN api.pkg_definition.udt_id)
    is
        t_sqlerrm      VARCHAR2(4000);
        t_trace        VARCHAR2(4000);
    begin
        IF (api.pkg_columnquery.VALUE(a_jobid, 'LSPId') IS NOT NULL)
        THEN
                bizmod_api.utl_licenseinfo.createjob(
                    a_procedure => 'APPLICATIONSAVEJOB',
                    a_description =>
                        'E-Services Application Saved Notify LSP Job ' || a_jobid,
                    a_argument1 => a_objectid,
                    a_argument2 => SYSDATE,
                    a_argument3 => a_jobid);
    
        end if;
    EXCEPTION
        WHEN OTHERS
        THEN
            t_sqlerrm := SQLERRM;
            t_trace := DBMS_UTILITY.format_error_backtrace;

            INSERT INTO bizmod_api.e_process_log_t(seq,
                                                   processjob,
                                                   info,
                                                   errmsg,
                                                   bktrace)
                 VALUES (0,
                         'APPLICATIONSAVE',
                         'Application Object Id: ' || a_jobid || chr(13) ||
                         'Process Id: ' || a_objectid,
                         t_sqlerrm,
                         t_trace);
    end;                                  
END;
/


GRANT EXECUTE ON BIZMOD_API.PKG_ABIS TO PUBLIC;
