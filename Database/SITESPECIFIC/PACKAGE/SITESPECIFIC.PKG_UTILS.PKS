CREATE OR REPLACE PACKAGE SITESPECIFIC.pkg_utils
IS
    -- **************************************************************************
    -- File:        PKG_UTILS.PKS
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

    TYPE t_number IS TABLE OF NUMBER;

    SUBTYPE udt_id IS api.pkg_definition.udt_id;

    SUBTYPE udt_idlist IS api.pkg_definition.udt_idlist;

    FUNCTION generaterows(v_inf NUMBER, v_sup NUMBER)
        RETURN t_number
        PIPELINED;

    PROCEDURE validatedate(a_objectid      udt_id,
                           a_asofdate      DATE,
                           a_programtype   VARCHAR2,
                           a_monthname     VARCHAR2,
                           a_operationdate NUMBER,
                           a_year          NUMBER);

    ----------------------------------------------------------------------------------------------------
    --  DatePlus()     --Public
    --  This procedure adds a_PlusDays days to the a_Date1 date field and sets the a_Date2Name date field with a_Date1 + a_PlusDays.
    ----------------------------------------------------------------------------------------------------
    PROCEDURE dateplus(a_objectid      NUMBER,
                       a_asofdate      DATE,
                       a_date1         DATE,
                       a_plusdays      NUMBER,
                       a_date2name     VARCHAR2);

    -----------------------------------------------------------------------------
    -- DoesObjectExist() - PUBLIC
    --  Convenience function used to determine if a given ObjectId exists to prevent
    --  no_data_found exception and unnecessary exception blocks.
    -----------------------------------------------------------------------------
    FUNCTION doesobjectexist(a_objectid udt_id)
        RETURN BOOLEAN;

    /********************************
    ** This is used to copy the ProcessId of a process to
    ** the process that created it
    *********************************/
    PROCEDURE copyidtocreatedbyprocess(a_objectid udt_id, a_asofdate DATE);


    /*******************************
     ** RaiseErrPairedLT()
     ** This will run on completion of Enter Application, Add Permit/LT and Issue License
     **   to verify that any Paired Master LTs for any existing LTs are added to the Application.
    ****************************** */
    PROCEDURE raiseerrpairedlt(a_objectid      udt_id,
                               a_asofdate      DATE,
                               a_jobid         udt_id);

    /*-----------------------------
    -- DeleteLicenseMA() PUBLIC
    -- This procedurally deletes the relationship from the License
    --  to the Mailing Address as a workaround to not being able
    --  to procedurally delete a rel that has a procedure running on descructor.
    -----------------------------*/
    PROCEDURE deletelicensema(a_objectid udt_id, a_asofdate DATE);

    /*-----------------------------
    -- Verify() PUBLIC
    -- This procedure triggers post verify for the objectid passed in
    -----------------------------*/
    PROCEDURE verify(a_objectid      udt_id,
                     a_asofdate      DATE,
                     a_verifyobjectid udt_id);

    PROCEDURE sendemail(a_fromaddress   VARCHAR2,
                        a_toaddress     VARCHAR2,
                        a_subject       VARCHAR2,
                        a_body          VARCHAR2,
                        a_mimetype      VARCHAR2 DEFAULT 'text/plain');

    /*---------------------------------------------------------------------------
     * ValidateTimeFields()
     * Created by Daniel Grosskopf (CXUSA) on 1/21/14
     * Can be run on any object/job/process.  Validates details on the object
     * which use the "Time Entry" Domain to ensure they have a valid time entered.
     *-------------------------------------------------------------------------*/
    PROCEDURE validatetimedetails(a_objectid udt_id, a_asofdate DATE);

    ----------------------------------------------------------------------------------------------------
    -- Calc Batch Progress
    -- Query the sitespecific.LicBatchLicType_Xref_t table to check how many records have   -- been committed.
    ----------------------------------------------------------------------------------------------------
    /*Function CalcBatchProgress (a_JobId   udt_id
                                 ) return number;
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
                                    a_createdddate  DATE);

    /*---------------------------------------------------------------------------
     * MergeObjects()
     * Created by Mike Lott (CXUSA) on 11/17/2015
     *-------------------------------------------------------------------------*/
    PROCEDURE mergeobjects(a_objectid udt_id, a_asofdate DATE);
END pkg_utils;
/


GRANT EXECUTE ON SITESPECIFIC.PKG_UTILS TO POSSEEXTENSIONS;

GRANT EXECUTE ON SITESPECIFIC.PKG_UTILS TO PUBLIC;
