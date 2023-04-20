CREATE OR REPLACE PROCEDURE SITESPECIFIC.tl_reprintcertific(
    a_objectid     IN     NUMBER,
    a_msg             OUT VARCHAR2)
IS
    -- **************************************************************************
    -- File:        TL_REPRINTCERTIFIC.PRC
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

    t_printleadcardjobdefid   NUMBER
        := api.pkg_configquery.objectdefidforname(
               'j_tl_PrintLeadCertiifcates');
    t_printleadcardjobid      NUMBER;
    t_processleadcarddefid    NUMBER
        := api.pkg_configquery.objectdefidforname(
               'p_tl_PrintLeadCertificate');
    t_schedulekey             NUMBER;
    t_arguments               VARCHAR2(4000) := NULL;
BEGIN
    api.pkg_logicaltransactionupdate.resettransaction();

    t_printleadcardjobid   :=
        api.pkg_jobupdate.new(t_printleadcardjobdefid,
                              'This Job is printing the LEAD certifiactes',
                              '',
                              NULL);

    --Set Arguments for the Process to create on the process server
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'JobId',
                                        t_printleadcardjobid);
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'ProcessTypeId',
                                        t_processleadcarddefid);
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'AsOfDate',
                                        SYSDATE - (1 / 24));
    scheduler.pkg_scheduler.addargument(t_arguments,
                                        'EffectiveUser',
                                        'POSSESYS');

    --schedule item to be handled by the process server
    t_schedulekey   :=
        scheduler.pkg_scheduler.scheduleitem(
            SYSDATE - (1 / 24),
            2,
            'nvo_CreateProcess',
            t_arguments,
               'Create process of type '
            || TO_CHAR(t_processleadcarddefid)
            || ' on job '
            || TO_CHAR(t_printleadcardjobid),
            2);
    api.pkg_columnupdate.setvalue(a_objectid, 'ScheduleKey', t_schedulekey);

    INSERT INTO sendleadcertificateemail_t
         VALUES (sendleadcertificateemail_s.NEXTVAL,
                 NULL,
                 a_objectid,
                 NULL,
                 t_printleadcardjobid);

    api.pkg_logicaltransactionupdate.endtransaction();
EXCEPTION
    WHEN OTHERS THEN
        a_msg   :=
               'RQS_AUTORUNREPORTS(EXCEPTION): '
            || dbms_utility.format_error_backtrace
            || ' :: '
            || SQLERRM;

        NULL;
END;
/


GRANT EXECUTE ON SITESPECIFIC.TL_REPRINTCERTIFIC TO POSSEEXTENSIONS;
