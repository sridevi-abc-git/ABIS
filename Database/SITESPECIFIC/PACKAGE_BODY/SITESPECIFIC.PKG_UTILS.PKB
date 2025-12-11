CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_utils
IS
    -- **************************************************************************
    -- File:        PKG_UTILS.PKB
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
    -- 12/10/2025 PK          For type 94 when address in outside CA no error -- Added this code FOr type 94 Pawan 12/10/2025
    -- **************************************************************************


    FUNCTION generaterows(v_inf NUMBER, v_sup NUMBER)
        RETURN t_number
        PIPELINED
    AS
    BEGIN
        FOR i IN v_inf .. v_sup
        LOOP
            PIPE ROW (i);
        END LOOP;

        RETURN;
    END;

    /*
      ValidateDate()
      this Procedure will make sure the day entered is valid in that month
    */

    PROCEDURE validatedate(a_objectid      udt_id,
                           a_asofdate      DATE,
                           a_programtype   VARCHAR2,
                           a_monthname     VARCHAR2,
                           a_operationdate NUMBER,
                           a_year          NUMBER)
    IS
        t_test   DATE;
    BEGIN
        SELECT CASE
                   WHEN a_monthname IS NOT NULL
                    AND a_operationdate IS NOT NULL
                    AND a_year IS NOT NULL THEN
                       TO_DATE(
                              a_monthname
                           || ' '
                           || a_operationdate
                           || ', '
                           || a_year,
                           'MONTH DD, YYYY')
               END
          INTO t_test
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS THEN
            api.pkg_errors.raiseerror(
                -20000,
                   'Under "'
                || a_programtype
                || '," the Operation Date entered is not valid for the month of "'
                || a_monthname
                || '."');
    END;


    ----------------------------------------------------------------------------------------------------
    --  DatePlus()     --Public
    --  This procedure adds a_PlusDays days to the a_Date1 date field and sets the a_Date2Name date field with a_Date1 + a_PlusDays.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE dateplus(a_objectid      NUMBER,
                       a_asofdate      DATE,
                       a_date1         DATE,
                       a_plusdays      NUMBER,
                       a_date2name     VARCHAR2)
    IS
        t_sumeddate   DATE;
    BEGIN
        IF a_date1 IS NOT NULL THEN
            t_sumeddate   := a_date1 + a_plusdays;
            api.pkg_columnupdate.setvalue(a_objectid,
                                          a_date2name,
                                          t_sumeddate);
        END IF;
    END dateplus;

    -----------------------------------------------------------------------------
    -- DoesObjectExist() - PUBLIC
    --  Convenience function used to determine if a given ObjectId exists to prevent
    --  no_data_found exception and unnecessary exception blocks.
    -----------------------------------------------------------------------------
    FUNCTION doesobjectexist(a_objectid udt_id)
        RETURN BOOLEAN
    IS
        t_objectid   udt_id;
    BEGIN
        SELECT o.objectid
          INTO t_objectid
          FROM api.objects o
         WHERE o.objectid = a_objectid;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN FALSE;
    END;

    /********************************
    ** This is used to copy the ProcessId of a process to
    ** the process that created it
    *********************************/
    PROCEDURE raiseerrpairedlt(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id)
    IS
        t_raiseerr       VARCHAR2(1);
        t_pairedmaster   VARCHAR2(100);
        t_pairedlt       VARCHAR2(100);
    BEGIN
        FOR c
            IN (SELECT ltp.pairedltcmasterobjectid
                  FROM query.r_appprimarylicensetype  aplt
                       JOIN query.r_priltltcatprimary ltr
                           ON ltr.primarylicensetypeobjectid =
                              aplt.licensetypeobjectid
                       JOIN query.r_licensetypecategorypaired ltp
                           ON ltp.pairedltcobjectid =
                              ltr.licensetypecategoryobjectid
                 WHERE aplt.applicationobjectid = a_jobid)
        LOOP
            t_raiseerr   := 'Y';

            BEGIN
                --check the application to ensure the paired type exists there...
                SELECT 'N'
                  INTO t_raiseerr
                  FROM query.r_appprimarylicensetype  aplt2
                       JOIN query.o_primarylicensetype plt
                           ON plt.objectid = aplt2.licensetypeobjectid
                 WHERE aplt2.applicationobjectid = a_jobid
                   AND plt.licensetypecode =
                       api.pkg_columnquery.VALUE(c.pairedltcmasterobjectid,
                                                 'LicenseTypeCode');
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    BEGIN
                        --check the license we are changing to ensure the paired type exists there...
                        SELECT 'N'
                          INTO t_raiseerr
                          FROM query.r_applicationlicense  l
                               JOIN query.r_licenselicensetype lt
                                   ON lt.licensejobid = l.licensejobid
                               JOIN api.jobstatuses js
                                   ON js.jobtypeid =
                                      api.pkg_configquery.objectdefidforname(
                                          'j_LicenseType')
                                  AND js.statustype NOT IN ('C', 'X')
                         WHERE l.applicationjobid = a_jobid
                           AND api.pkg_columnquery.VALUE(lt.licensetypejobid,
                                                         'LicenseTypeCode') =
                               api.pkg_columnquery.VALUE(
                                   c.pairedltcmasterobjectid,
                                   'LicenseTypeCode')
                           AND api.pkg_columnquery.VALUE(lt.licensetypejobid,
                                                         'StatusId') =
                               js.statusid;
                    EXCEPTION
                        WHEN NO_DATA_FOUND THEN
                            NULL;
                        WHEN TOO_MANY_ROWS THEN
                            t_raiseerr   := 'N';
                    END;
                WHEN TOO_MANY_ROWS THEN
                    t_raiseerr   := 'N';
            END;
             -- For type 94 when address in outside CA no error -- Added this code FOr type 94 Pawan 12/02/2025
                BEGIN 
                SELECT 'N'
                  INTO t_raiseerr
                  FROM query.r_appprimarylicensetype  aplt2
                       JOIN query.o_primarylicensetype plt
                           ON plt.objectid = aplt2.licensetypeobjectid
                 WHERE aplt2.applicationobjectid = a_jobid
                   AND plt.licensetypecode = '94'
                   and  api.pkg_columnquery.VALUE(a_jobid, 'PremisesAddressLocation') = 'In USA, Outside CA';
        
              EXCEPTION
                WHEN NO_DATA_FOUND THEN
                NULL;
                       WHEN TOO_MANY_ROWS THEN
                            t_raiseerr   := 'N';
                    END;
                     
            EXIT WHEN t_raiseerr = 'N';
        END LOOP;

        IF t_raiseerr = 'Y' THEN
              SELECT concatlist2(
                         udt_aggrstring(
                             api.pkg_columnquery.VALUE(
                                 ltp.pairedltcmasterobjectid,
                                 'LicenseTypeCode'),
                             ' or ')),
                     api.pkg_columnquery.VALUE(aplt.licensetypeobjectid,
                                               'LicenseTypeCode')
                INTO t_pairedmaster, t_pairedlt
                FROM query.r_appprimarylicensetype aplt
                     JOIN query.r_priltltcatprimary ltr
                         ON ltr.primarylicensetypeobjectid =
                            aplt.licensetypeobjectid
                     JOIN query.r_licensetypecategorypaired ltp
                         ON ltp.pairedltcobjectid =
                            ltr.licensetypecategoryobjectid
               WHERE aplt.applicationobjectid = a_jobid
            GROUP BY aplt.licensetypeobjectid;
            
          IF t_pairedlt = '94' THEN  -- For type 94 when address in outside CA no error -- Added this code FOr type 94 Pawan 12/02/2025
          api.pkg_errors.raiseerror(
                -20000,
                   'CA Licensee must hold License Type '
                || t_pairedmaster
                || ' to get License Type '
                ||  t_pairedlt
                || '.'); -- For type 94 when address in outside CA no error -- Added this code FOr type 94 Pawan 12/02/2025
          Else
            api.pkg_errors.raiseerror(
                -20000,
                   'A License Type '
                || t_pairedlt
                || ' cannot exist without a License Type '
                || t_pairedmaster
                || '.');
        END IF;
        END IF;
    END raiseerrpairedlt;

    /*-----------------------------
    -- DeleteLicenseMA() PUBLIC
    -- This procedurally deletes the relationship from the License
    --  to the Mailing Address as a workaround to not being able
    --  to procedurally delete a rel that has a procedure running on descructor.
    -----------------------------*/
    PROCEDURE deletelicensema(a_objectid udt_id, a_asofdate DATE)
    IS
        t_relid   udt_id;
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'DeleteMailingAddress') =
           'Y' THEN
            SELECT r.relationshipid
              INTO t_relid
              FROM query.r_licenseaddrmailing r
             WHERE r.licensejobid = a_objectid;

            api.pkg_columnupdate.setvalue(t_relid,
                                          'RunProcedureOnDeletion',
                                          'Y');
            api.pkg_relationshipupdate.remove(t_relid);
        ELSE
            NULL;
        END IF;
    END deletelicensema;

    PROCEDURE verify(a_objectid      udt_id,
                     a_asofdate      DATE,
                     a_verifyobjectid udt_id)
    IS
    BEGIN
        api.pkg_objectupdate.verify(a_verifyobjectid);
    END verify;

    /*---------------------------------------------------------------------------
       * SendEmail()
       *
       *-------------------------------------------------------------------------*/

    PROCEDURE sendemail(a_fromaddress   VARCHAR2,
                        a_toaddress     VARCHAR2,
                        a_subject       VARCHAR2,
                        a_body          VARCHAR2,
                        a_mimetype      VARCHAR2 DEFAULT 'text/plain')
    IS
        t_emailid   api.pkg_definition.udt_id;
    BEGIN
        api.pkg_logicaltransactionupdate.resettransaction();

        t_emailid   :=
            extension.pkg_sendmail.send(a_fromaddress => a_fromaddress,
                                        a_toaddress => a_toaddress,
                                        a_subject   => a_subject,
                                        a_body      => a_body,
                                        a_mimetype  => a_mimetype);

        api.pkg_logicaltransactionupdate.endtransaction();
    END;

    /*---------------------------------------------------------------------------
     * ValidateTimeFields()
     * Created by Daniel Grosskopf (CXUSA) on 1/21/14
     * Can be run on any object/job/process.  Validates details on the object
     * which use the "Time Entry" Domain to ensure they have a valid time entered.
     *-------------------------------------------------------------------------*/
    PROCEDURE validatetimedetails(a_objectid udt_id, a_asofdate DATE)
    IS
        t_time         VARCHAR2(4);
        t_timenumber   NUMBER;
        t_timelength   NUMBER;
        t_hrs          NUMBER;
        t_mins         NUMBER;
    BEGIN
        FOR c
            IN (SELECT cd.name, cd.label
                  FROM api.objects  o
                       JOIN api.objectdefs od
                           ON od.objectdefid = o.objectdefid
                       JOIN api.columndefs cd
                           ON cd.objectdefid = o.objectdefid
                       JOIN api.domains d ON d.domainid = cd.domainid
                 WHERE o.objectid = a_objectid
                   AND d.name = 'Time Entry')
        LOOP
            t_time   := api.pkg_columnquery.VALUE(a_objectid, c.name);

            IF t_time IS NOT NULL                          /*and t_Time != 0*/
                                  THEN
                BEGIN
                    t_timenumber   := TO_NUMBER(t_time);
                EXCEPTION
                    WHEN OTHERS THEN
                        api.pkg_errors.raiseerror(
                            -20000,
                            '"' || c.label || '" only allows numbers.');
                END;

                t_timelength   := LENGTH(t_time);

                IF t_timelength < 3 THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           '"'
                        || c.label
                        || '" must have hours and minutes entered.');
                END IF;

                IF t_timelength = 3 THEN
                    t_hrs    := SUBSTR(t_time, 1, 1);
                    t_mins   := SUBSTR(t_time, 2);
                ELSE
                    t_hrs    := TO_NUMBER(SUBSTR(t_time, 1, 2));
                    t_mins   := TO_NUMBER(SUBSTR(t_time, 3));
                END IF;

                IF t_hrs > 12
                OR t_hrs < 1 THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           '"'
                        || c.label
                        || '" must have an hour between 1 and 12.');
                END IF;

                IF t_mins > 59
                OR t_mins < 0 THEN
                    api.pkg_errors.raiseerror(
                        -20000,
                           '"'
                        || c.label
                        || '" must have minutes entered between 00 and 59.');
                END IF;
            END IF;
        END LOOP;
    END;

    ----------------------------------------------------------------------------------------------------
    -- Calc Batch Progress
    -- Query the sitespecific.LicBatchLicType_Xref_t table to check how many records have been committed.
    ----------------------------------------------------------------------------------------------------
    /*Function CalcBatchProgress (a_JobId   udt_id
                                ) return number is
      l_TotalBatch     number;
      l_RunningTotal   number;
      l_PctDone        number;
    Begin
      -- populate the total of the batch
      select count(*)
        into l_TotalBatch
        from sitespecific.Batch_Tracking_Log x -- sitespecific.LicBatchLicType_Xref_t x
       where x.LicenseBatchJobId = a_JobId;
      --
      --populate the running total
      select count(*)
        into l_RunningTotal
        from sitespecific.Batch_Tracking_Log x -- sitespecific.LicBatchLicType_Xref_t x
       where x.LicenseBatchJobId = a_JobId
         and nvl(TOBEPROCESSEDIND,3) in (1,2,3); --could be 1, 2 or 3

      -- so as not to divide by zero...
      If l_TotalBatch = 0 then
          l_PctDone := 0;
      else
          select (l_RunningTotal/l_TotalBatch)* 100
            into l_PctDone
            from dual;
      end if;
      --

      return l_PctDone;
      --
    End;
  */
    /*---------------------------------------------------------------------------
     * UpdateExternalProcess()
     * Created by Andy Patterson (CXUSA) on 8/31/15
     * Procedure used as the Modify procedure for the External object o_Process
     *-------------------------------------------------------------------------*/
    PROCEDURE updateexternalprocess(a_processid     NUMBER,
                                    a_scheduledstartdate DATE,
                                    a_seqnum        NUMBER,
                                    a_datecompleted DATE,
                                    a_scheduledcompletedate DATE,
                                    a_outcome       VARCHAR2,
                                    a_jobid         NUMBER,
                                    a_completedbyuserid NUMBER,
                                    a_candelete     VARCHAR2,
                                    a_canmodify     VARCHAR2,
                                    a_cancomplete   VARCHAR2,
                                    a_createdddate  DATE)
    IS
    BEGIN
        api.pkg_processupdate.modify(a_processid,
                                     NULL,
                                     a_scheduledstartdate,
                                     a_scheduledcompletedate,
                                     TO_DATE(NULL));

        IF a_outcome IS NOT NULL THEN
            api.pkg_processupdate.complete(a_processid, a_outcome);
        END IF;
    END;

    /*---------------------------------------------------------------------------
     * MergeObjects()
     * Created by Mike Lott (CXUSA) on 11/17/2015
     *-------------------------------------------------------------------------*/
    PROCEDURE mergeobjects(a_objectid udt_id, a_asofdate DATE)
    IS
        t_dupecount         INT;
        t_correctid         udt_id;
        t_mergeidlist       udt_idlist;
        t_mergeobjecttype   VARCHAR2(20);
        t_jobid             udt_id;
        t_objectdeftypeid   udt_id;
    BEGIN
        SELECT objectdeftypeid
          INTO t_objectdeftypeid
          FROM api.objects
         WHERE objectid = a_objectid;

        IF t_objectdeftypeid <> 2 THEN
            t_jobid   :=
                api.pkg_columnquery.numericvalue(a_objectid, 'JobId');
        ELSE
            t_jobid   := a_objectid;
        END IF;

        t_mergeobjecttype   :=
            api.pkg_columnquery.VALUE(t_jobid, 'MergeObjectTypes');
        pkg_debug.putline(
               'Made it to the MergeObjects procedure. ObjectId: '
            || TO_CHAR(t_jobid)
            || ' - Merge Object Type: '
            || t_mergeobjecttype);

        IF t_mergeobjecttype IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                'Object Merge: You must select an Object Type to merge.');
        END IF;

        --Now get the object to keep
        t_correctid   := NULL;

        BEGIN
            IF t_mergeobjecttype = 'Address' THEN
                SELECT mergeaddressid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_address
                 WHERE addressmergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            ELSIF t_mergeobjecttype = 'Attorney' THEN
                SELECT mergeattorneyid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_attorney
                 WHERE attorneymergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            ELSIF t_mergeobjecttype = 'Company' THEN
                SELECT mergecompanyid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_company
                 WHERE companymergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            ELSIF t_mergeobjecttype = 'Escrow' THEN
                SELECT mergeescrowid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_escrow
                 WHERE escrowmergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            ELSIF t_mergeobjecttype = 'Person' THEN
                SELECT mergepersonid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_person
                 WHERE personmergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            ELSIF t_mergeobjecttype = 'Protestant' THEN
                SELECT mergeprotestantid
                  INTO t_correctid
                  FROM query.r_dupeobjectmerge_protestant
                 WHERE protestantmergejobid = t_jobid
                   AND correctmergeobject = 'Y';
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                t_correctid   := NULL;
            WHEN TOO_MANY_ROWS THEN
                api.pkg_errors.raiseerror(
                    -20000,
                       t_mergeobjecttype
                    || ' Merge: Please select only ONE object to keep.');
        END;

        IF t_correctid IS NULL THEN
            api.pkg_errors.raiseerror(
                -20000,
                t_mergeobjecttype || ' Merge: No object to keep was selected');
        END IF;

        --Now get the object to be merged
        IF t_mergeobjecttype = 'Address' THEN
            SELECT mergeaddressid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_address
             WHERE addressmergejobid = t_jobid
               AND correctmergeobject = 'N';
        ELSIF t_mergeobjecttype = 'Attorney' THEN
            SELECT mergeattorneyid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_attorney
             WHERE attorneymergejobid = t_jobid
               AND correctmergeobject = 'N';
        ELSIF t_mergeobjecttype = 'Company' THEN
            SELECT mergecompanyid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_company
             WHERE companymergejobid = t_jobid
               AND correctmergeobject = 'N';
        ELSIF t_mergeobjecttype = 'Escrow' THEN
            SELECT mergeescrowid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_escrow
             WHERE escrowmergejobid = t_jobid
               AND correctmergeobject = 'N';
        ELSIF t_mergeobjecttype = 'Person' THEN
            SELECT mergepersonid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_person
             WHERE personmergejobid = t_jobid
               AND correctmergeobject = 'N';
        ELSIF t_mergeobjecttype = 'Protestant' THEN
            SELECT mergeprotestantid
              BULK COLLECT INTO t_mergeidlist
              FROM query.r_dupeobjectmerge_protestant
             WHERE protestantmergejobid = t_jobid
               AND correctmergeobject = 'N';
        END IF;

        t_dupecount   := t_mergeidlist.COUNT;
        pkg_debug.putline(
            'Made it to Merge() - Dupe Count: ' || TO_CHAR(t_dupecount));
        pkg_debug.putline('Keeping Object: ' || t_correctid);

        FOR i IN 1 .. t_dupecount
        LOOP
            pkg_debug.putline('Merging Object: ' || t_mergeidlist(i));
        END LOOP;

        IF t_dupecount > 0 THEN
            api.pkg_columnupdate.setvalue(t_jobid,
                                          'MergedObjectCount',
                                          t_dupecount);
            api.pkg_objectupdate.merge(t_correctid, t_mergeidlist);
        ELSE
            -- Something is amiss...
            api.pkg_errors.raiseerror(
                -20000,
                   t_mergeobjecttype
                || ' Merge: No objects to merge were selected.');
        END IF;
    END mergeobjects;
END pkg_utils;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_UTILS TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_UTILS TO PUBLIC;
