CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_tlutilities
IS
    -- **************************************************************************
    -- File:        PKG_TLUTILITIES.PKB
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

    /******************************************************************
    checklicensenumber is run in the TRACe/LEAD system when supplied a license number
    it checks wheter or not it is a valid license in ABIS
    ******************************************************************/
    PROCEDURE checklicensenumber(a_objectid      udt_id,
                                 a_asofdate      DATE,
                                 a_licensenumber VARCHAR2)
    IS
        t_licenseobjectid   VARCHAR2(10);
        t_object            api.udt_objectlist;
        t_dba               VARCHAR2(4000);
        t_premisesaddress   VARCHAR2(4000);
    BEGIN
        t_object   := api.udt_objectlist();

        extension.pkg_cxproceduralsearch.initializesearch('j_License');
        extension.pkg_cxproceduralsearch.searchbyindex('ExternalFileNum',
                                                       a_licensenumber,
                                                       NULL,
                                                       FALSE);
        extension.pkg_cxproceduralsearch.performsearch(t_object, 'or', 'or');

        IF t_object.COUNT >= 1 THEN
            t_licenseobjectid   := t_object(1).objectid;

            SELECT l.doingbusinessas, l.premisesaddress
              INTO t_dba, t_premisesaddress
              FROM query.j_license l
             WHERE l.objectid = t_licenseobjectid;
        ELSE
            api.pkg_errors.raiseerror(
                -20000,
                   'License Number: '
                || a_licensenumber
                || ' is not valid license number');
        END IF;
    END checklicensenumber;

    /******************************************************************
    GenerateLEADCertificate is run on the LEAD class object when the email LEAD
    certificate button is pressed, If the Student passed the LEAD class create a
    process on the process server that will be used to Print the LEAD certificate
    ******************************************************************/
    PROCEDURE generateleadcertificates(a_objectid udt_id, a_asofdate DATE)
    IS
        t_printleadcardjobdefid   udt_id
            := api.pkg_configquery.objectdefidforname(
                   'j_tl_PrintLeadCertiifcates');
        t_printleadcardjobid      udt_id;
        t_processleadcarddefid    udt_id
            := api.pkg_configquery.objectdefidforname(
                   'p_tl_PrintLeadCertificate');
        t_processleadcardobjid    udt_id;
        t_passemailobjectid       udt_id;
        t_attachdocumnet          BOOLEAN;
        t_arguments               VARCHAR2(4000);
        t_schedulekey             udt_id;
    BEGIN
        --Loop through the completed registrations for the LEAD class and send an email to each

        t_printleadcardjobid   :=
            api.pkg_jobupdate.new(
                t_printleadcardjobdefid,
                'This Job is printing the LEAD certifiactes',
                '',
                NULL);

        FOR i
            IN (SELECT sr.objectid,
                       sr.fromaddresscolname,
                       sr.toaddresscolname,
                       sr.subjectcolname,
                       sr.bodycolname,
                       sr.passed,
                       sr.failed
                  FROM query.o_tl_studentregistration  sr
                       JOIN api.relationships r
                           ON r.fromobjectid = sr.objectid
                       JOIN query.o_tl_leadclassinfo lc
                           ON lc.objectid = r.toobjectid
                 WHERE lc.objectid = a_objectid
                   AND lc.emailleadcertificates = 'Y'
                   AND sr.iscompleteregistration = 'Y')
        LOOP
            t_arguments           := NULL;
            t_passemailobjectid   := i.objectid;

            IF i.passed = 'Y' THEN --Create the process to print the LEAD certificate
                --Set Arguments for the Process to create on the process server
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'JobId',
                                                    t_printleadcardjobid);
                scheduler.pkg_scheduler.addargument(t_arguments,
                                                    'ProcessTypeId',
                                                    t_processleadcarddefid);
                --scheduler.pkg_Scheduler.AddArgument( t_Arguments, 'Outcome', 'Printed' );
                --set the scheduled start date to null so that the process server picks it up immediately
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

                /* t_ProcessLeadCardObjId := api.pkg_processupdate.New(t_PrintLeadCardJobId,
                                                                     t_ProcessLeadCardDefId,
                                                                     'Print LEAD Certifiacte for Student Registration: ' || i.Objectid,
                                                                     null,
                                                                     null,
                                                                     null);*/

                --t_PassEmailObjectId := t_ProcessLeadCardObjId;
                api.pkg_columnupdate.setvalue(i.objectid,
                                              'ScheduleKey',
                                              t_schedulekey);

                INSERT INTO sendleadcertificateemail_t
                     VALUES (sendleadcertificateemail_s.NEXTVAL,
                             NULL,
                             i.objectid,
                             NULL,
                             t_printleadcardjobid);

                UPDATE abc.tl_studentauditlog
                   SET certissue        = 'Y',
                       certissuecount   = NVL(certissuecount, 0) + 1
                 WHERE objectid = i.objectid;
            END IF;

            IF i.failed = 'Y' THEN --Send the email notifation that the Student did not pass the LEAD class
                extension.pkg_sendmail.sendposseemail(i.objectid,
                                                      SYSDATE,
                                                      i.fromaddresscolname,
                                                      i.toaddresscolname,
                                                      NULL,
                                                      NULL,
                                                      i.subjectcolname,
                                                      i.bodycolname,
                                                      NULL,
                                                      NULL,
                                                      'Y');
            END IF;
        END LOOP;

        --Set the Email LEAD Certificate boolean back to false to avoid issues with repeat sending
        api.pkg_columnupdate.setvalue(a_objectid,
                                      'EmailLEADCertificates',
                                      'N');
    END generateleadcertificates;

    /******************************************************************
    SendLEADClassEmail is run on the TRACE class object when the email LEAD
    certificate button is pressed
    ******************************************************************/
    PROCEDURE relateleadstudentstoprocess(a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid            udt_id;
        t_leadcertid       NUMBER;
        t_srobjectid       NUMBER;
        t_newrelid         NUMBER;
        t_printtosrendid   udt_id
            := api.pkg_configquery.endpointidforname(
                   'p_tl_PrintLeadCertificate',
                   'StudentRegistration');
    BEGIN
        /**************************************************
        select sr.ObjectId, sr.FromAddressColName, sr.ToAddressColName, sr.SubjectColName, sr.BodyColName
                      from query.o_Tl_Studentregistration sr
                      join api.relationships r on r.FromObjectId = sr.objectid
                      join query.o_Tl_Leadclassinfo lc on lc.ObjectId = r.ToObjectId
                        where lc.ObjectId = a_Objectid
                          and lc.EmailLEADCertificates = 'Y'
                          and sr.IsCompleteRegistration = 'Y'
        ***************************************************/

        t_jobid   := api.pkg_columnquery.VALUE(a_objectid, 'JobId');

        SELECT MIN(slc.leadcertid)
          INTO t_leadcertid
          FROM sitespecific.sendleadcertificateemail_t slc
         WHERE slc.processeddate IS NULL
           AND slc.jobid = t_jobid;

        SELECT slc2.srobjectid
          INTO t_srobjectid
          FROM sitespecific.sendleadcertificateemail_t slc2
         WHERE slc2.leadcertid = t_leadcertid;

        UPDATE sitespecific.sendleadcertificateemail_t slc3
           SET slc3.processid = a_objectid, slc3.processeddate = SYSDATE
         WHERE slc3.leadcertid = t_leadcertid;

        t_newrelid   :=
            api.pkg_relationshipupdate.new(t_printtosrendid,
                                           a_objectid,
                                           t_srobjectid);
    END relateleadstudentstoprocess;

    /******************************************************************
    SendLEADClassEmail is run on the TRACE class object when the email LEAD
    certificate button is pressed
    ******************************************************************/
    PROCEDURE sendleadclassemail(a_objectid udt_id, a_asofdate DATE)
    IS
    BEGIN
        /**************************************************
        select sr.ObjectId, sr.FromAddressColName, sr.ToAddressColName, sr.SubjectColName, sr.BodyColName
                      from query.o_Tl_Studentregistration sr
                      join api.relationships r on r.FromObjectId = sr.objectid
                      join query.o_Tl_Leadclassinfo lc on lc.ObjectId = r.ToObjectId
                        where lc.ObjectId = a_Objectid
                          and lc.EmailLEADCertificates = 'Y'
                          and sr.IsCompleteRegistration = 'Y'
        ***************************************************/


        extension.pkg_sendmail.sendposseemail(a_objectid,
                                              SYSDATE,
                                              'FromEmailAddress',
                                              'EmailAddress',
                                              NULL,
                                              NULL,
                                              'EmailSubject',
                                              'EmailBody',
                                              NULL,
                                              'LeadCertificate',
                                              'N');
    END sendleadclassemail;

    /******************************************************************

      --Loop through the completed registrations for the LEAD class and send an email to each
        for c in () loop
        extension.pkg_sendmail.SendPosseEmail(c.objectid,
                                              sysdate,
                                              c.fromaddresscolname,
                                              c.toaddresscolname,
                                              null,
                                              null,
                                              c.subjectcolname,
                                              c.bodycolname,
                                              null,
                                              'LeadCertificate',
                                              'N');
        end loop;

      --Set the Email LEAD Certificate boolean back to false to avoid issues with repeat sending
      api.pkg_columnupdate.SetValue(a_Objectid, 'EmailLEADCertificates', 'N');
    *******************************************************************/

    /******************************************************************
    SendLEADCancelledEmail is run on the TRACE class object when the email LEAD
    certificate button is pressed
    ******************************************************************/
    PROCEDURE sendleadcancelledemail(a_objectid udt_id, a_asofdate DATE)
    IS
    BEGIN
        --Loop through the completed registrations for the LEAD class and send an email to each
        FOR i
            IN (SELECT sr.objectid,
                       sr.fromaddresscolname,
                       sr.toaddresscolname,
                       'ClassCancelledEmailBody'    bodycolname,
                       'ClassCancelledEmailSubject' subjectcolname
                  FROM query.o_tl_studentregistration  sr
                       JOIN api.relationships r
                           ON r.fromobjectid = sr.objectid
                       JOIN query.o_tl_leadclassinfo lc
                           ON lc.objectid = r.toobjectid
                 WHERE lc.objectid = a_objectid
                   AND lc.classcancelled = 'Y'
                   AND sr.iscompleteregistration = 'Y')
        LOOP
            extension.pkg_sendmail.sendposseemail(i.objectid,
                                                  SYSDATE,
                                                  i.fromaddresscolname,
                                                  i.toaddresscolname,
                                                  NULL,
                                                  NULL,
                                                  i.subjectcolname,
                                                  i.bodycolname,
                                                  NULL,
                                                  NULL,
                                                  'Y');
        END LOOP;
    END sendleadcancelledemail;

    /******************************************************************
    SendTRACECaseEmail is run on the TRACE Complaint object when the complaint
    is submitted.
    ******************************************************************/
    PROCEDURE sendtracecaseemail(a_objectid udt_id, a_asofdate DATE)
    IS
        t_body                   VARCHAR2(4000);
        t_fromemail              VARCHAR2(4000);
        t_toemail                VARCHAR2(4000);
        t_phonenumber            VARCHAR2(60);
        t_formattedphonenumber   VARCHAR2(50);
        t_emailid                NUMBER;
    BEGIN
        --Get details of the TRACE complaint and send an Email to Pat Deasy
        t_body        :=
            api.pkg_columnquery.VALUE(a_objectid, 'DescriptionOfComplaint');
        t_fromemail   := api.pkg_columnquery.VALUE(a_objectid, 'Email');
        t_toemail     := 'trace@abc.ca.gov';
        t_phonenumber   :=
            api.pkg_columnquery.VALUE(a_objectid, 'PhoneNumber');
        --t_FormattedPhoneNumber := substr()

        t_emailid     :=
            extension.pkg_sendmail.send(
                t_fromemail,
                t_toemail,
                'TRACE Complaint, Phone Number:' || t_phonenumber,
                t_body,
                NULL,
                NULL);
    END sendtracecaseemail;

    PROCEDURE checkstudentemailaddr(a_objectid      udt_id,
                                    a_asofdate      DATE,
                                    a_emailaddr     VARCHAR2,
                                    a_trainingdate  DATE)
    IS
        ln_cnt   NUMBER := 0;
    BEGIN
        IF (a_emailaddr IS NOT NULL
        AND TRUNC(SYSDATE) < TRUNC(a_trainingdate)) THEN
            SELECT NVL(COUNT(emailaddress), 0)
              INTO ln_cnt
              FROM query.o_tl_studentregistration  s
                   INNER JOIN query.r_leadclassregistration r
                       ON (r.studentregistrationid = s.objectid)
             WHERE r.leadclassid =
                   (SELECT leadclassid
                      FROM query.r_leadclassregistration
                     WHERE studentregistrationid = a_objectid)
               AND UPPER(emailaddress) = UPPER(a_emailaddr);

            IF (ln_cnt > 1) THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       'Student Email Address: '
                    || a_emailaddr
                    || ' already register for this class');
            END IF;
        END IF;
    END checkstudentemailaddr;

    --procedure ClassList(a_ObjectId     IN  udt_Id,
    --                    a_ASOfDate     IN  date,
    --                    a_TrainingDate IN  date,
    --                    a_ClassList    OUT SYS_REFCURSOR) IS
    --
    --BEGIN
    --
    ----    OPEN a_ClassList FOR
    --null;
    --
    --END;

    PROCEDURE unregisterstudent(a_objectid     IN     udt_id,
                                a_asofdate     IN     DATE,
                                a_emailaddress IN     VARCHAR2,
                                a_confirmation IN     NUMBER,
                                a_msg             OUT VARCHAR2)
    IS
        objectid       NUMBER := a_objectid;
        emailaddress   VARCHAR2(600);
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction();

        -- was an object id passed
        IF (objectid IS NULL) THEN
            BEGIN
                -- was confirmation number passed
                IF (a_confirmation IS NOT NULL) THEN
                    SELECT objectid, emailaddress
                      INTO objectid, emailaddress
                      FROM query.o_tl_studentregistration
                     WHERE confirmationnumber = a_confirmation;

                    IF (a_emailaddress IS NOT NULL) THEN
                        -- make sure email is the same for confirmation number
                        IF (emailaddress != a_emailaddress) THEN
                            a_msg      :=
                                'Confirmation Number, Email Address validation failed';
                            objectid   := NULL;
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;
            END;
        END IF;

        IF (objectid IS NULL) THEN
            -- was email address passed
            IF (a_emailaddress IS NOT NULL
            AND a_confirmation IS NULL) THEN
                BEGIN
                    SELECT objectid
                      INTO objectid
                      FROM query.o_tl_studentregistration
                     WHERE LOWER(emailaddress) = LOWER(a_emailaddress);
                EXCEPTION
                    WHEN NO_DATA_FOUND THEN
                        NULL;
                    WHEN TOO_MANY_ROWS THEN
                        a_msg      :=
                            'Multiple students found with same email address, please enter your confirmation number with your email address.';
                        objectid   := NULL;
                END;
            END IF;
        END IF;

        IF (objectid IS NOT NULL) THEN
            -- remove selected object
            api.pkg_objectupdate.remove(objectid);
        ELSE
            IF (a_msg IS NULL) THEN
                a_msg   := 'Your student record was not found';
            END IF;
        END IF;

        api.pkg_logicaltransactionupdate.endtransaction();
    EXCEPTION
        WHEN OTHERS THEN
            a_msg   :=
                   'Unregister Student(EXCEPTION): '
                || dbms_utility.format_error_backtrace
                || ' :: '
                || SQLERRM;
    END unregisterstudent;
END pkg_tlutilities;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_TLUTILITIES TO POSSEEXTENSIONS;
