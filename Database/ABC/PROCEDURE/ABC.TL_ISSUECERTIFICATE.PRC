CREATE OR REPLACE PROCEDURE ABC.tl_issuecertificate(
    p_studentobjectid IN  NUMBER,
    p_passfail     IN     VARCHAR2,
    p_message         OUT VARCHAR2,
    p_code            OUT NUMBER)
IS
    -- **************************************************************************
    -- File:        TL_ISSUECERTIFICATE.PRC
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
    -- 08/21/2018 TJL         Initial Check-in
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

    IF (UPPER(p_passfail) = 'PASS') THEN
        t_printleadcardjobid   :=
            api.pkg_jobupdate.new(
                t_printleadcardjobdefid,
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

        api.pkg_columnupdate.setvalue(p_studentobjectid,
                                      'ScheduleKey',
                                      t_schedulekey);

        INSERT INTO sitespecific.sendleadcertificateemail_t
             VALUES (sitespecific.sendleadcertificateemail_s.NEXTVAL,
                     NULL,
                     p_studentobjectid,
                     NULL,
                     t_printleadcardjobid);

        UPDATE abc.tl_studentauditlog
           SET certissue = 'Y', certissuecount = NVL(certissuecount, 0) + 1
         WHERE objectid = p_studentobjectid;
    ELSE
        extension.pkg_sendmail.sendposseemail(
            p_studentobjectid,
            SYSDATE,
            api.pkg_columnquery.VALUE(p_studentobjectid,
                                      'fromaddresscolname'),
            api.pkg_columnquery.VALUE(p_studentobjectid, 'toaddresscolname'),
            NULL,
            NULL,
            api.pkg_columnquery.VALUE(p_studentobjectid, 'subjectcolname'),
            api.pkg_columnquery.VALUE(p_studentobjectid, 'bodycolname'),
            NULL,
            NULL,
            'Y');
    END IF;

    api.pkg_logicaltransactionupdate.endtransaction();
EXCEPTION
    WHEN OTHERS THEN
        p_message   :=
               'Re-schedule Certificate: '
            || SQLERRM
            || ' :: '
            || dbms_utility.format_error_backtrace;
        p_code   := -1;
END;
/


GRANT EXECUTE ON ABC.TL_ISSUECERTIFICATE TO POSSEEXTENSIONS;
