CREATE OR REPLACE FUNCTION ABCREPORTS.PriorityAlphaList (
    p_parms        IN OUT t_parameters,
    p_status_ind   IN OUT VARCHAR2)
    RETURN BLOB
IS
    -- ****************************************************************************
    -- File:        PriorityAlphaList.Fnc
    -- Author:      Pawanjit Kaur
    --
    -- $Rev$
    -- $Date$
    -- Last Changed By:  $Author$
    --
    -- Description:
    --
    --
    -- History:
    -------------------------------------------------------------------------------
    --    Date                  Comment
    -- 07/26/2021    PK   25397    Initial File created
    -- ---------------------------------------------------------------------------
    CURSOR OriginalOnSaleGeneral (
        p_county        IN VARCHAR2,
        p_office_list   IN T_OFFICEOBJECT,
        p_startdate        DATE,
        p_enddate          DATE)
    IS
        WITH
            AppIds
            AS
                (SELECT  /*+ materialize */
                        DISTINCT
                        a.OBJECTID,
                        a.PRIMARYLicensee,
                        mpa.OFFICE,
                        API.PKG_COLUMNQUERY.VALUE (rel.toobjectid,
                                                   'OfficeId')
                            officeobjectid
                   FROM QUERY.J_MANAGEPRIORITYAPPLICATIONS  mpa
                        JOIN query.r_ManagePriorityAppsApp r
                            ON r.MANAGEPRIORITYAPPSJOBID = mpa.JOBID
                        JOIN mart.APPLICATION a
                            ON r.APPLICATIONJOBID = a.objectid
                        JOIN API.RELATIONSHIPS rel
                            ON     rel.fromOBJECTID = mpa.objectid
                               AND rel.ENDPOINTID IN
                                       (api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'CACounty'),
                                        api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'PDOffice'))
                  WHERE     a.ORIGINALONSALEGENERAL = 'Y'
                        AND TRUNC (mpa.CREATEDDATE) BETWEEN p_startdate
                                                        AND p_enddate
                        AND mpa.COUNTYCODE = p_county)
          SELECT LicenseNumber,
                 MailingAddress,
                 LPAD (EPType, 5 * NestLevel + LENGTH (EPType) - 5, ' ')
                     EPName,
                 LegalEntityName,
                 Person_CompanyName,
                 BirthDate,
                 Office
            FROM (    SELECT DISTINCT
                             (SELECT DISTINCT rd3.ToEndPointName
                                FROM api.Relationships r3
                                     JOIN api.Relationshipdefs rd3
                                         ON     rd3.RelationshipDefId =
                                                r3.RelationshipDefId
                                            AND r3.EndPointId = rd3.FromEndPointId
                               WHERE     r3.RelationshipId = r.RelationshipId
                                     AND r3.EndPointId = r.EndPointId)
                                 EPType,
                             r.FromObjectId
                                 LEObjId,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'PrimaryLicensee')
                                 LegalEntityName,
                             --  api.pkg_ColumnQuery.Value(r.TOOBJECTID , 'OfficeName' ) OfficeName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'dup_FormattedName')
                                 Person_CompanyName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'SortColumn_Stored')
                                 sortkey,
                             nvl(api.pkg_ColumnQuery.Value( r.FromObjectId , 
                                                            'RelatedJobFileNo' ),
                                    api.pkg_ColumnQuery.Value(r.TOOBJECTID ,
                                                            'ExternalFileNum'))
                                 LicenseNumber,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'ReportMailingAddress1Line') MailingAddress,
                             --  api.pkg_ColumnQuery.Value( f.ObjectId , 'BirthDate' )BirthDate,
                             (SELECT DISTINCT RootObjectId
                                FROM query.r_Legalentityroot
                               WHERE NodeObjectId = r.FromObjectId)
                                 Root_LE,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'hierarchylevel_stored')
                                 HL,
                             (SELECT office
                                FROM appids
                               WHERE objectid = r.toobjectid)
                                 office,
                             LEVEL
                                 NestLevel,
                             (SELECT op.birthdate
                                FROM query.r_LegalEntityPerson lep
                                     JOIN query.o_person op
                                         ON     op.objectid = lep.PersonObjectId
                                            AND lep.LegalEntityObjectId =
                                                r.FromObjectId)
                                 birthdate
                        FROM api.Relationships r
                             JOIN api.Objects f ON f.ObjectId = r.FromObjectId
                  -- on api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Person')
                  START WITH     r.ToObjectId IN (SELECT objectid FROM appids) -- 505710844--172630057     --Application or License ObjectId
                             AND f.ObjectDefId =
                                 api.pkg_ConfigQuery.ObjectDefIdForName (
                                     'o_LegalEntity')
                             -- and r.endpointid in  api.pkg_configquery.endpointidforname('o_LegalEntity', 'person')
                             AND r.EndPointId NOT IN
                                     (api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerStockholder'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'ParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'Root'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12ARoot'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12AParent'))
                  CONNECT BY NOCYCLE     r.ToObjectId = PRIOR r.FromObjectId
                                     AND f.ObjectDefId =
                                         api.pkg_ConfigQuery.ObjectDefIdForName (
                                             'o_LegalEntity')
                                     AND r.FromObjectId NOT IN
                                             (SELECT objectid FROM appids) -- 505710844 --172630057     --Application or License ObjectId
                                     AND r.EndPointId NOT IN
                                             (api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'OfficerStockholder'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'ParentEntity'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Root'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'P12ARoot'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Node'))
                    ORDER BY r.FromObjectId, LEVEL)
        ORDER BY sortkey;

    CURSOR OriginalOffSaleGeneral (
        p_county        IN VARCHAR2,
        p_office_list   IN T_OFFICEOBJECT,
        p_startdate        DATE,
        p_enddate          DATE)
    IS
        WITH
            AppIds
            AS
                (SELECT  /*+ materialize */
                        DISTINCT
                        a.OBJECTID,
                        a.PRIMARYLicensee,
                        mpa.OFFICE,
                        API.PKG_COLUMNQUERY.VALUE (rel.toobjectid,
                                                   'OfficeId')
                            officeobjectid
                   FROM QUERY.J_MANAGEPRIORITYAPPLICATIONS  mpa
                        JOIN query.r_ManagePriorityAppsApp r
                            ON r.MANAGEPRIORITYAPPSJOBID = mpa.JOBID
                        JOIN mart.APPLICATION a
                            ON r.APPLICATIONJOBID = a.objectid
                        JOIN API.RELATIONSHIPS rel
                            ON     rel.fromOBJECTID = mpa.objectid
                               AND rel.ENDPOINTID IN
                                       (api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'CACounty'),
                                        api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'PDOffice'))
                  WHERE     a.ORIGINALOFFSALEGENERAL = 'Y'
                        AND TRUNC (mpa.CREATEDDATE) BETWEEN p_startdate
                                                        AND p_enddate
                        AND mpa.OFFICEID IN
                                (SELECT officeobjectid
                                   FROM TABLE (p_office_list))
                        AND mpa.COUNTYCODE = p_county)
          SELECT LicenseNumber,
                 MailingAddress,
                 LPAD (EPType, 5 * NestLevel + LENGTH (EPType) - 5, ' ')
                     EPName,
                 LegalEntityName,
                 Person_CompanyName,
                 BirthDate,
                 Office
            FROM (    SELECT DISTINCT
                             (SELECT DISTINCT rd3.ToEndPointName
                                FROM api.Relationships r3
                                     JOIN api.Relationshipdefs rd3
                                         ON     rd3.RelationshipDefId =
                                                r3.RelationshipDefId
                                            AND r3.EndPointId = rd3.FromEndPointId
                               WHERE     r3.RelationshipId = r.RelationshipId
                                     AND r3.EndPointId = r.EndPointId)
                                 EPType,
                             r.FromObjectId
                                 LEObjId,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'PrimaryLicensee')
                                 LegalEntityName,
                             --  api.pkg_ColumnQuery.Value(r.TOOBJECTID , 'OfficeName' ) OfficeName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'dup_FormattedName')
                                 Person_CompanyName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'SortColumn_Stored')
                                 sortkey,
                               nvl(api.pkg_ColumnQuery.Value( r.FromObjectId , 
                                                            'RelatedJobFileNo' ),
                                    api.pkg_ColumnQuery.Value(r.TOOBJECTID ,
                                                            'ExternalFileNum'))
                                 LicenseNumber,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'ReportMailingAddress1Line') MailingAddress,
                             --  api.pkg_ColumnQuery.Value( f.ObjectId , 'BirthDate' )BirthDate,
                             (SELECT DISTINCT RootObjectId
                                FROM query.r_Legalentityroot
                               WHERE NodeObjectId = r.FromObjectId)
                                 Root_LE,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'hierarchylevel_stored')
                                 HL,
                             (SELECT office
                                FROM appids
                               WHERE objectid = r.toobjectid)
                                 office,
                             LEVEL
                                 NestLevel,
                             (SELECT op.birthdate
                                FROM query.r_LegalEntityPerson lep
                                     JOIN query.o_person op
                                         ON     op.objectid = lep.PersonObjectId
                                            AND lep.LegalEntityObjectId =
                                                r.FromObjectId)
                                 birthdate
                        FROM api.Relationships r
                             JOIN api.Objects f ON f.ObjectId = r.FromObjectId
                  -- on api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Person')
                  START WITH     r.ToObjectId IN (SELECT objectid FROM appids) -- 505710844--172630057     --Application or License ObjectId
                             AND f.ObjectDefId =
                                 api.pkg_ConfigQuery.ObjectDefIdForName (
                                     'o_LegalEntity')
                             -- and r.endpointid in  api.pkg_configquery.endpointidforname('o_LegalEntity', 'person')
                             AND r.EndPointId NOT IN
                                     (api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerStockholder'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'ParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'Root'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12ARoot'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12AParent'))
                  CONNECT BY NOCYCLE     r.ToObjectId = PRIOR r.FromObjectId
                                     AND f.ObjectDefId =
                                         api.pkg_ConfigQuery.ObjectDefIdForName (
                                             'o_LegalEntity')
                                     AND r.FromObjectId NOT IN
                                             (SELECT objectid FROM appids) -- 505710844 --172630057     --Application or License ObjectId
                                     AND r.EndPointId NOT IN
                                             (api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'OfficerStockholder'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'ParentEntity'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Root'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'P12ARoot'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Node'))
                    ORDER BY r.FromObjectId, LEVEL)
        ORDER BY sortkey;

    CURSOR IntercountyOnSaleGeneral (
        p_county        IN VARCHAR2,
        p_office_list   IN T_OFFICEOBJECT,
        p_startdate        DATE,
        p_enddate          DATE)
    IS
        WITH
            AppIds
            AS
                (SELECT  /*+ materialize */
                        DISTINCT
                        a.OBJECTID,
                        a.PRIMARYLicensee,
                        mpa.OFFICE,
                        API.PKG_COLUMNQUERY.VALUE (rel.toobjectid,
                                                   'OfficeId')
                            officeobjectid
                   FROM QUERY.J_MANAGEPRIORITYAPPLICATIONS  mpa
                        JOIN query.r_ManagePriorityAppsApp r
                            ON r.MANAGEPRIORITYAPPSJOBID = mpa.JOBID
                        JOIN mart.APPLICATION a
                            ON r.APPLICATIONJOBID = a.objectid
                        JOIN API.RELATIONSHIPS rel
                            ON     rel.fromOBJECTID = mpa.objectid
                               AND rel.ENDPOINTID IN
                                       (api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'CACounty'),
                                        api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'PDOffice'))
                  WHERE     a.INTERCOUNTYONSALEGENERAL = 'Y'
                        AND TRUNC (mpa.CREATEDDATE) BETWEEN p_startdate
                                                        AND p_enddate
                        AND mpa.OFFICEID IN
                                (SELECT officeobjectid
                                   FROM TABLE (p_office_list))
                        AND mpa.COUNTYCODE = p_county)
          SELECT LicenseNumber,
                 MailingAddress,
                 LPAD (EPType, 5 * NestLevel + LENGTH (EPType) - 5, ' ')
                     EPName,
                 LegalEntityName,
                 Person_CompanyName,
                 BirthDate,
                 Office
            FROM (    SELECT DISTINCT
                             (SELECT DISTINCT rd3.ToEndPointName
                                FROM api.Relationships r3
                                     JOIN api.Relationshipdefs rd3
                                         ON     rd3.RelationshipDefId =
                                                r3.RelationshipDefId
                                            AND r3.EndPointId = rd3.FromEndPointId
                               WHERE     r3.RelationshipId = r.RelationshipId
                                     AND r3.EndPointId = r.EndPointId)
                                 EPType,
                             r.FromObjectId
                                 LEObjId,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'PrimaryLicensee')
                                 LegalEntityName,
                             --  api.pkg_ColumnQuery.Value(r.TOOBJECTID , 'OfficeName' ) OfficeName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'dup_FormattedName')
                                 Person_CompanyName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'SortColumn_Stored')
                                 sortkey,
                              nvl(api.pkg_ColumnQuery.Value( r.FromObjectId , 
                                                            'RelatedJobFileNo' ),
                                    api.pkg_ColumnQuery.Value(r.TOOBJECTID ,
                                                            'ExternalFileNum'))
                                 LicenseNumber,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'ReportMailingAddress1Line') MailingAddress,
                             --  api.pkg_ColumnQuery.Value( f.ObjectId , 'BirthDate' )BirthDate,
                             (SELECT DISTINCT RootObjectId
                                FROM query.r_Legalentityroot
                               WHERE NodeObjectId = r.FromObjectId)
                                 Root_LE,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'hierarchylevel_stored')
                                 HL,
                             (SELECT office
                                FROM appids
                               WHERE objectid = r.toobjectid)
                                 office,
                             LEVEL
                                 NestLevel,
                             (SELECT op.birthdate
                                FROM query.r_LegalEntityPerson lep
                                     JOIN query.o_person op
                                         ON     op.objectid = lep.PersonObjectId
                                            AND lep.LegalEntityObjectId =
                                                r.FromObjectId)
                                 birthdate
                        FROM api.Relationships r
                             JOIN api.Objects f ON f.ObjectId = r.FromObjectId
                  -- on api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Person')
                  START WITH     r.ToObjectId IN (SELECT objectid FROM appids) -- 505710844--172630057     --Application or License ObjectId
                             AND f.ObjectDefId =
                                 api.pkg_ConfigQuery.ObjectDefIdForName (
                                     'o_LegalEntity')
                             -- and r.endpointid in  api.pkg_configquery.endpointidforname('o_LegalEntity', 'person')
                             AND r.EndPointId NOT IN
                                     (api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerStockholder'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'ParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'Root'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12ARoot'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12AParent'))
                  CONNECT BY NOCYCLE     r.ToObjectId = PRIOR r.FromObjectId
                                     AND f.ObjectDefId =
                                         api.pkg_ConfigQuery.ObjectDefIdForName (
                                             'o_LegalEntity')
                                     AND r.FromObjectId NOT IN
                                             (SELECT objectid FROM appids) -- 505710844 --172630057     --Application or License ObjectId
                                     AND r.EndPointId NOT IN
                                             (api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'OfficerStockholder'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'ParentEntity'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Root'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'P12ARoot'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Node'))
                    ORDER BY r.FromObjectId, LEVEL)
        ORDER BY sortkey;

    CURSOR IntercountyOffSaleGeneral (
        p_county        IN VARCHAR2,
        p_office_list   IN T_OFFICEOBJECT,
        p_startdate        DATE,
        p_enddate          DATE)
    IS
        WITH
            AppIds
            AS
                (SELECT  /*+ materialize */
                        DISTINCT
                        a.OBJECTID,
                        a.PRIMARYLicensee,
                        mpa.OFFICE,
                        API.PKG_COLUMNQUERY.VALUE (rel.toobjectid,
                                                   'OfficeId')
                            officeobjectid
                   FROM QUERY.J_MANAGEPRIORITYAPPLICATIONS  mpa
                        JOIN query.r_ManagePriorityAppsApp r
                            ON r.MANAGEPRIORITYAPPSJOBID = mpa.JOBID
                        JOIN mart.APPLICATION a
                            ON r.APPLICATIONJOBID = a.objectid
                        JOIN API.RELATIONSHIPS rel
                            ON     rel.fromOBJECTID = mpa.objectid
                               AND rel.ENDPOINTID IN
                                       (api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'CACounty'),
                                        api.pkg_configquery.endpointidforname (
                                            'j_ManagePriorityApplications',
                                            'PDOffice'))
                  WHERE     a.INTERCOUNTYOFFSALEGENERAL = 'Y'
                        AND TRUNC (mpa.CREATEDDATE) BETWEEN p_startdate
                                                        AND p_enddate
                        AND mpa.OFFICEID IN
                                (SELECT officeobjectid
                                   FROM TABLE (p_office_list))
                        AND mpa.COUNTYCODE = p_county)
          SELECT LicenseNumber,
                 MailingAddress,
                 LPAD (EPType, 5 * NestLevel + LENGTH (EPType) - 5, ' ')
                     EPName,
                 LegalEntityName,
                 Person_CompanyName,
                 BirthDate,
                 Office
            FROM (    SELECT DISTINCT
                             (SELECT DISTINCT rd3.ToEndPointName
                                FROM api.Relationships r3
                                     JOIN api.Relationshipdefs rd3
                                         ON     rd3.RelationshipDefId =
                                                r3.RelationshipDefId
                                            AND r3.EndPointId = rd3.FromEndPointId
                               WHERE     r3.RelationshipId = r.RelationshipId
                                     AND r3.EndPointId = r.EndPointId)
                                 EPType,
                             r.FromObjectId
                                 LEObjId,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'PrimaryLicensee')
                                 LegalEntityName,
                             --  api.pkg_ColumnQuery.Value(r.TOOBJECTID , 'OfficeName' ) OfficeName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'dup_FormattedName')
                                 Person_CompanyName,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'SortColumn_Stored')
                                 sortkey,
                             nvl(api.pkg_ColumnQuery.Value( r.FromObjectId , 
                                                            'RelatedJobFileNo' ),
                                    api.pkg_ColumnQuery.Value(r.TOOBJECTID ,
                                                            'ExternalFileNum'))
                                 LicenseNumber,
                             api.pkg_ColumnQuery.VALUE (r.TOOBJECTID,
                                                        'ReportMailingAddress1Line') MailingAddress,
                             --  api.pkg_ColumnQuery.Value( f.ObjectId , 'BirthDate' )BirthDate,
                             (SELECT DISTINCT RootObjectId
                                FROM query.r_Legalentityroot
                               WHERE NodeObjectId = r.FromObjectId)
                                 Root_LE,
                             api.pkg_ColumnQuery.VALUE (r.FromObjectId,
                                                        'hierarchylevel_stored')
                                 HL,
                             (SELECT office
                                FROM appids
                               WHERE objectid = r.toobjectid)
                                 office,
                             LEVEL
                                 NestLevel,
                             (SELECT op.birthdate
                                FROM query.r_LegalEntityPerson lep
                                     JOIN query.o_person op
                                         ON     op.objectid = lep.PersonObjectId
                                            AND lep.LegalEntityObjectId =
                                                r.FromObjectId)
                                 birthdate
                        FROM api.Relationships r
                             JOIN api.Objects f ON f.ObjectId = r.FromObjectId
                  -- on api.pkg_ConfigQuery.EndPointIdForName('o_LegalEntity', 'Person')
                  START WITH     r.ToObjectId IN (SELECT objectid FROM appids) -- 505710844--172630057     --Application or License ObjectId
                             AND f.ObjectDefId =
                                 api.pkg_ConfigQuery.ObjectDefIdForName (
                                     'o_LegalEntity')
                             -- and r.endpointid in  api.pkg_configquery.endpointidforname('o_LegalEntity', 'person')
                             AND r.EndPointId NOT IN
                                     (api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerStockholder'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'ParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'Root'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'OfficerParentEntity'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12ARoot'),
                                      api.pkg_ConfigQuery.EndPointIdForName (
                                          'o_LegalEntity',
                                          'P12AParent'))
                  CONNECT BY NOCYCLE     r.ToObjectId = PRIOR r.FromObjectId
                                     AND f.ObjectDefId =
                                         api.pkg_ConfigQuery.ObjectDefIdForName (
                                             'o_LegalEntity')
                                     AND r.FromObjectId NOT IN
                                             (SELECT objectid FROM appids) -- 505710844 --172630057     --Application or License ObjectId
                                     AND r.EndPointId NOT IN
                                             (api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'OfficerStockholder'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'ParentEntity'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Root'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'P12ARoot'),
                                              api.pkg_ConfigQuery.EndPointIdForName (
                                                  'o_LegalEntity',
                                                  'Node'))
                    ORDER BY r.FromObjectId, LEVEL)
        ORDER BY sortkey;


    lblob_csv        BLOB;
    lv_csv_row       VARCHAR2 (8096);
    lv_status_msg    VARCHAR2 (4000);
    lv_report_name   VARCHAR (150) := p_parms.get_value ('REPORT_NAME');
   -- v_counties       VARCHAR (200) := p_parms.get_value ('COUNTIES');
   -- v_office         VARCHAR (100) := p_parms.get_value ('OFFICEOBJECTID');
BEGIN

--    DBMS_OUTPUT.put_line ('COUNTIES;' || v_counties);
--    DBMS_OUTPUT.put_line ('REPORT_NAME;' || lv_report_name);
--    DBMS_OUTPUT.put_line ('OFFICEOBJECTID;' || v_office);
--    DBMS_OUTPUT.put_line ('startdate ' || p_parms.get_value ('startdate'));
    
     DBMS_LOB.createtemporary(lblob_csv, TRUE, DBMS_LOB.call);
    --lv_status_msg := 'No report date found';
    p_parms.upd_value ('REPORT_DATE',
                       TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI PM'));

    IF (UPPER (lv_report_name) = 'PRIORITY ALPHA LIST (ORIGINAL ON-SALE)')
    THEN
        FOR rec
            IN OriginalOnSaleGeneral (
                  p_parms.get_value ('COUNTIES'),
                   rqs_utils.BuildOfficeList (
                      p_parms.get_value ('OFFICEOBJECTID'),
                                            lv_status_msg),
                   TO_DATE (p_parms.get_value ('START_DATE'), 'MM/DD/YYYY'),
                   TO_DATE (p_parms.get_value ('END_DATE'), 'MM/DD/YYYY'))
        LOOP
        
            lv_csv_row :=
                   '"'
                || rec.LicenseNumber
                || '","'
                || rec.MailingAddress
                || '","'
                || rec.EPName
                || '","'
                || rec.LegalEntityName
                || '","'
                || rec.Person_CompanyName
                || '","'
                || rec.BirthDate
                || '","'
                || rec.Office
                || '","'
                || CHR(13);
--                || CHR(10);   
            DBMS_LOB.append (lblob_csv, UTL_RAW.cast_to_raw (lv_csv_row));
        END LOOP;
    ELSE
        IF (UPPER (lv_report_name) =
            'PRIORITY ALPHA LIST (ORIGINAL OFF-SALE)')
        THEN
            FOR rec
                IN OriginalOffSaleGeneral (
                       p_parms.get_value ('COUNTIES'),
                       rqs_utils.BuildOfficeList (
                           p_parms.get_value ('OFFICEOBJECTID'),
                           lv_status_msg),
                              TO_DATE (p_parms.get_value ('START_DATE'), 'MM/DD/YYYY'),
                              TO_DATE (p_parms.get_value ('END_DATE'), 'MM/DD/YYYY'))
            LOOP
                lv_csv_row :=
                             '"'
                || rec.LicenseNumber
                || '","'
                || rec.MailingAddress
                || '","'
                || rec.EPName
                || '","'
                || rec.LegalEntityName
                || '","'
                || rec.Person_CompanyName
                || '","'
                || rec.BirthDate
                || '","'
                || rec.Office
                || '","'
                || CHR(13);
                DBMS_LOB.append (lblob_csv, UTL_RAW.cast_to_raw (lv_csv_row));
            END LOOP;
        ELSE
            IF (UPPER (lv_report_name) =
                'PRIORITY ALPHA LIST (INTERCOUNTY OFF-SALE)')
            THEN
                FOR rec
                    IN IntercountyOffSaleGeneral (
                           p_parms.get_value ('COUNTIES'),
                           rqs_utils.BuildOfficeList (
                               p_parms.get_value ('OFFICEOBJECTID'),
                               lv_status_msg),
                   TO_DATE (p_parms.get_value ('START_DATE'), 'MM/DD/YYYY'),
                   TO_DATE (p_parms.get_value ('END_DATE'), 'MM/DD/YYYY'))
                LOOP
                    lv_csv_row :=
                                  '"'
                || rec.LicenseNumber
                || '","'
                || rec.MailingAddress
                || '","'
                || rec.EPName
                || '","'
                || rec.LegalEntityName
                || '","'
                || rec.Person_CompanyName
                || '","'
                || rec.BirthDate
                || '","'
                || rec.Office
                || '","'
                || CHR(13);
                    DBMS_LOB.append (lblob_csv,
                                     UTL_RAW.cast_to_raw (lv_csv_row));
                END LOOP;
            ELSE
               
                    FOR rec
                        IN IntercountyOnSaleGeneral (
                               p_parms.get_value ('COUNTIES'),
                               rqs_utils.BuildOfficeList (
                                   p_parms.get_value ('OFFICEOBJECTID'),
                                   lv_status_msg),
                   TO_DATE (p_parms.get_value ('START_DATE'), 'MM/DD/YYYY'),
                   TO_DATE (p_parms.get_value ('END_DATE'), 'MM/DD/YYYY'))
                    LOOP
                        lv_csv_row :=
                               '"'
                || rec.LicenseNumber
                || '","'
                || rec.MailingAddress
                || '","'
                || rec.EPName
                || '","'
                || rec.LegalEntityName
                || '","'
                || rec.Person_CompanyName
                || '","'
                || rec.BirthDate
                || '","'
                || rec.Office
                || '","'
                || CHR(13);
                        DBMS_LOB.append (lblob_csv,
                                         UTL_RAW.cast_to_raw (lv_csv_row));
                    END LOOP;
                END IF;
            END IF;
        END IF;

    RETURN lblob_csv;
EXCEPTION
    WHEN OTHERS
    THEN
        rqs_utils.LOG (
            p_log_type          => 'E',
            p_job_id            => p_parms.get_value ('JOB_ID'),
            p_seq               => p_parms.get_value ('SEQ'),
            p_source            => 'PRIORITYALPHALIST',
            p_msg               => SQLERRM,
            p_additional_data   => NULL,
            p_error_trace       => DBMS_UTILITY.format_error_backtrace);

        p_status_ind := 'E';
        RETURN UTL_RAW.cast_to_raw (
                      'ERROR: '
                   || SQLERRM
                   || CHR (10)
                   || CHR (13)
                   || 'TRACE: '
                   || DBMS_UTILITY.format_error_backtrace);
END PriorityAlphaList;
/
