CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_tllead
AS
    -- **************************************************************************
    -- File:        PKG_TLLEAD.PKB
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

    PROCEDURE createregistrationconfirmid(a_objectid udt_id, a_asofdate DATE)
    IS
        t_confirmationnumber   VARCHAR2(10);
    BEGIN
        IF api.pkg_columnquery.VALUE(a_objectid, 'ConfirmationNumber')
               IS NULL THEN
            SELECT sitespecific.leadregconfirmnum.NEXTVAL
              INTO t_confirmationnumber
              FROM DUAL;

            api.pkg_columnupdate.setvalue(a_objectid,
                                          'ConfirmationNumber',
                                          t_confirmationnumber);
        END IF;
    END createregistrationconfirmid;


    PROCEDURE createstudentregistration(a_objectid udt_id, a_asofdate DATE)
    IS
        t_newstudentobjid        udt_id;
        t_newstudentobjdefid     udt_id
            := api.pkg_configquery.objectdefidforname(
                   'o_TL_StudentRegistration');
        t_newstudentrelid        udt_id;
        t_newstudentclassdefid   udt_id
            := api.pkg_configquery.objectdefidforname('o_TL_LEADClassInfo');
        t_endpoint               udt_id
            := api.pkg_configquery.endpointidforname(t_newstudentclassdefid,
                                                     'LEADClassRegistration');
        t_leadclassobjid         udt_id := a_objectid;
        t_studentname            VARCHAR2(50);
        t_emailaddr              VARCHAR2(255);
    BEGIN
        IF api.pkg_columnquery.VALUE(t_leadclassobjid, 'AddStudent') = 'Y' THEN
            t_newstudentobjid   :=
                api.pkg_objectupdate.new(t_newstudentobjdefid, a_asofdate);
            t_newstudentrelid   :=
                api.pkg_relationshipupdate.new(t_endpoint,
                                               t_leadclassobjid,
                                               t_newstudentobjid);

            t_studentname   :=
                api.pkg_columnquery.VALUE(t_leadclassobjid, 'StudentName');
            t_emailaddr   :=
                api.pkg_columnquery.VALUE(t_leadclassobjid, 'EmailAddress');

            api.pkg_columnupdate.setvalue(t_newstudentobjid,
                                          'StudentName',
                                          t_studentname);
            api.pkg_columnupdate.setvalue(t_newstudentobjid,
                                          'EmailAddress',
                                          t_emailaddr);
            api.pkg_columnupdate.setvalue(t_newstudentobjid,
                                          'EmailAddressConfirm',
                                          t_emailaddr);

            IF api.pkg_columnquery.VALUE(t_newstudentobjid,
                                         'ConfirmationNumber')
                   IS NULL THEN
                createregistrationconfirmid(t_newstudentobjid, a_asofdate);
            END IF;

            api.pkg_columnupdate.setvalue(t_newstudentobjid,
                                          'IsCompleteRegistration',
                                          'Y');
            api.pkg_columnupdate.setvalue(t_newstudentobjid,
                                          'CreatedDate',
                                          SYSDATE);

            api.pkg_columnupdate.removevalue(t_leadclassobjid, 'StudentName');
            api.pkg_columnupdate.removevalue(t_leadclassobjid,
                                             'EmailAddress');
            api.pkg_columnupdate.setvalue(t_leadclassobjid,
                                          'AddStudent',
                                          'N');

            INSERT INTO abc.tl_studentauditlog(objectid,
                                               classid,
                                               confirmationnumber,
                                               studentname,
                                               emailaddress,
                                               phonenumber,
                                               applicationentered,
                                               howentered)
                     VALUES (
                                t_newstudentobjid,
                                t_leadclassobjid,
                                api.pkg_columnquery.VALUE(
                                    t_newstudentobjid,
                                    'ConfirmationNumber'),
                                t_studentname,
                                t_emailaddr,
                                NULL,
                                'LEAD Roster',
                                'T');
        END IF;
    END createstudentregistration;
END pkg_tllead;
/
