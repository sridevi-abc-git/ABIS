CREATE OR REPLACE PACKAGE BODY SITESPECIFIC.pkg_gis
IS
    -- **************************************************************************
    -- File:        pkg_GIS.pkb
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
    -- 08/16/2018 TJL         Initial Check-in
    --08/20/2020 PK            Added SYNCGIS to sync GIS in Test
    -- **************************************************************************

    /*------------------------------------------------------------------------*
     * Global Constants
     *------------------------------------------------------------------------*/
	  /* --PREVIOUS
    g_namespace CONSTANT VARCHAR2 (100) := 'http://MCALABCABISWB6/abis/';
    --g_webservice CONSTANT VARCHAR2(50) := 'ESRIInterface';
    g_ServiceURL CONSTANT VARCHAR2 (100) := 'http://MCALABCABISWB6/abis/ESRIInterface.asmx/';
    */
    
    /*CURRENT*/
    -- PROD
    g_namespace CONSTANT VARCHAR2 (100) := 'https://abcweb.abc.ca.gov/';
    g_ServiceURL CONSTANT VARCHAR2 (100) := 'http://134.187.167.174/ABIS/ESRIInterface.asmx/';
    
    -- STAGE
    /*g_namespace CONSTANT VARCHAR2 (100) := 'https://abcwebstg.abc.ca.gov/';
    g_ServiceURL CONSTANT VARCHAR2 (100) := 'http://abcwebstg.abc.ca.gov/ABIS/ESRIInterface.asmx/';*/
    
    -- WALLET
    g_walletpath   CONSTANT VARCHAR2 (100) := 'file:D:/oracle/wallet_gis';

    /*------------------------------------------------------------------------*
     * AddQueryStringArg() -- PRIVATE
     *
     *   Format the given arguments into a proper URL query string.  Used by the
     * CallWebService procedure
     *------------------------------------------------------------------------*/
    PROCEDURE AddQueryStringArg (a_QueryStringArgs   IN OUT NOCOPY VARCHAR2,
                                 a_ArgumentName                    VARCHAR2,
                                 a_ArgumentValue                   VARCHAR2)
    IS
    BEGIN
        IF a_ArgumentValue IS NULL
        THEN
            RETURN;
        END IF;

        IF a_QueryStringArgs IS NOT NULL
        THEN
            a_QueryStringArgs :=
                   a_QueryStringArgs
                || '&'
                || a_ArgumentName
                || '='
                || UTL_URL.escape (a_ArgumentValue);
        ELSE
            a_QueryStringArgs :=
                a_ArgumentName || '=' || UTL_URL.escape (a_ArgumentValue);
        END IF;
    END;

    /*------------------------------------------------------------------------*
    * HttpGetClob() -- PRIVATE
    *
    *   Takes in a URL and returns am http request (clob)
    *------------------------------------------------------------------------*/
    FUNCTION HttpGetClob (a_Url               VARCHAR2,
                          a_QueryStringArgs   VARCHAR2 DEFAULT NULL)
        RETURN CLOB
    IS
        t_RequestQueryString   VARCHAR2 (32767);
        t_Request              UTL_HTTP.req;
        t_Response             UTL_HTTP.resp;
        t_Line                 VARCHAR2 (32767);
        t_Clob                 CLOB;
        t_Length               NUMBER;
    BEGIN
        t_RequestQueryString := a_QueryStringArgs;
        t_Length := LENGTH (t_RequestQueryString);
        UTL_HTTP.set_wallet (g_walletpath);
        t_Request := UTL_HTTP.begin_request (a_url, 'POST');

        BEGIN
            UTL_HTTP.set_header (t_Request, 'User-Agent', 'Mozilla/4.0');
            UTL_HTTP.set_header (t_Request,
                                 'Content-Type',
                                 'application/x-www-form-urlencoded');
            UTL_HTTP.set_header (t_Request, 'Content-Length', t_Length);
            UTL_HTTP.write_text (t_Request, t_RequestQueryString);
            t_Response := UTL_HTTP.get_response (t_Request);
        EXCEPTION
            WHEN OTHERS
            THEN
                UTL_HTTP.end_request (t_request);
                RAISE;
        END;

        DBMS_LOB.createtemporary (t_Clob, FALSE);

        BEGIN
            LOOP
                UTL_HTTP.read_line (t_Response, t_Line, TRUE);
                DBMS_LOB.writeappend (t_Clob, LENGTH (t_Line), t_Line);
            END LOOP;

            UTL_HTTP.end_response (t_Response);
        EXCEPTION
            WHEN UTL_HTTP.end_of_body
            THEN
                UTL_HTTP.end_response (t_Response);
            WHEN OTHERS
            THEN
                UTL_HTTP.end_response (t_response);
                RAISE;
        END;

        RETURN t_Clob;
    END;

    /*------------------------------------------------------------------------*
     * CallWebService() -- PRIVATE
     *------------------------------------------------------------------------*/
    FUNCTION callwebservice (a_operation VARCHAR2, a_parameters VARCHAR2)
        RETURN BOOLEAN
    IS
        t_request       XMLTYPE;
        t_response      XMLTYPE;
        t_XPath         VARCHAR2 (100);
        t_QueryString   VARCHAR2 (4000);
        t_RespCLOB      CLOB;
    BEGIN
        -- Format the request in XML format
        t_request :=
            xmltype (
                   '<'
                || a_operation
                || ' xmlns="'
                || g_namespace
                || '">'
                || a_parameters
                || '</'
                || a_operation
                || '>');

        -- Format the Operation into XML
        t_XPath := '/*[local-name() = "' || a_operation || '"]/*';

        -- Convert XML (request and operation) to Query String (URL)
        FOR a
            IN (SELECT *
                  FROM XMLTABLE (
                           t_XPath
                           PASSING t_request
                           COLUMNS node_name VARCHAR2 (100)
                                       PATH 'name(.)',
                                   node_value VARCHAR2 (100)
                                       PATH '.'))
        LOOP
            AddQueryStringArg (t_QueryString, a.node_name, a.node_value);
        END LOOP;

        DBMS_OUTPUT.put_line (
               'Web Service Request URL: '
            || g_ServiceURL
            || a_Operation
            || '?'
            || t_QueryString);

        -- Submit the request to the service and recieve the response
        t_RespCLOB :=
            HttpGetClob (g_ServiceURL || a_Operation, t_QueryString);
        DBMS_OUTPUT.put_line ('ResponseClob: ' || t_RespCLOB);

        t_Response := xmlType (t_RespCLOB);

        DBMS_OUTPUT.put_line (
               'response extract: '
            || t_response.EXTRACT ('boolean/text()',
                                   'xmlns="' || g_namespace || '"').getStringVal ());

        RETURN (t_response.EXTRACT ('boolean/text()',
                                    'xmlns="' || g_namespace || '"').getStringVal ()) =
               'true';
    END callwebservice;

    /*------------------------------------------------------------------------*
     *  GeocodeAddress() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE geocodeaddress (a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid     udt_id;
        --t_licensetypes   VARCHAR2(4000);
        --t_xml            VARCHAR2(4000);
        t_success   BOOLEAN;
    BEGIN
        IF    api.pkg_constantquery.VALUE ('ISPRODUCTION') = 'Y'
           OR api.pkg_constantquery.VALUE ('SYNCGIS') = 'Y'
        THEN                        -- Added SYNCGIS to sync GIS in Test Pawan
            t_jobid :=
                NVL (extension.pkg_common.jobidforprocess (a_objectid),
                     a_objectid);

            IF     api.pkg_columnquery.VALUE (t_jobid, 'OverriddenGeocodedX')
                       IS NOT NULL
               AND api.pkg_columnquery.VALUE (t_jobid, 'OverriddenGeocodedY')
                       IS NOT NULL
            THEN
                t_success := addaddresspointatlocation (t_jobid, a_asofdate);
            ELSE
                t_success := addaddressbygeocoding (t_jobid, a_asofdate);
            END IF;

            IF NOT t_success
            THEN
                api.pkg_columnupdate.setvalue (t_jobid,
                                               'GeolocationFailed',
                                               'Y');
            ELSE
                api.pkg_columnupdate.setvalue (t_jobid,
                                               'GeolocationFailed',
                                               'N');
            END IF;

            api.pkg_columnupdate.setvalue (t_jobid, 'IsGeocoded', 'Y');
        END IF;
    END geocodeaddress;

    /*------------------------------------------------------------------------*
     *  AddAddressByGeocoding() -- PUBLIC
     *------------------------------------------------------------------------*/
    FUNCTION addaddressbygeocoding (a_jobid udt_id, a_asofdate DATE)
        RETURN BOOLEAN
    IS
        t_licensetypes   VARCHAR2 (4000);
        t_xml            VARCHAR2 (4000);
        t_success        BOOLEAN;
    BEGIN
        t_licensetypes :=
            api.pkg_columnquery.VALUE (a_jobid, 'GISLicenseTypeCode');

        BEGIN
            SELECT    XMLELEMENT ("Street", ad.geocodeaddressline1)
                   || XMLELEMENT ("City", ad.usacity)
                   || XMLELEMENT ("State", ad.usastatecode)
                   || XMLELEMENT ("Zip", ad.zipcode)
                   || XMLELEMENT ("AppLicNumber", jo.externalfilenum)
                   || XMLELEMENT ("ObjectId", jo.jobid)
                   || XMLELEMENT ("LicenseType", t_licensetypes)
                   || XMLELEMENT ("JobType", jt.description)
              INTO t_xml
              FROM api.jobs  jo
                   JOIN api.jobtypes jt ON jo.jobtypeid = jt.jobtypeid
                   JOIN api.relationships re
                       ON     jo.jobid = re.fromobjectid
                          AND re.endpointid IN
                                  (api.pkg_configquery.endpointidforname (
                                       'j_Application',
                                       'Premises'),
                                   api.pkg_configquery.endpointidforname (
                                       'j_License',
                                       'Premises'))
                   JOIN query.o_address ad ON ad.objectid = re.toobjectid
             WHERE     jo.jobid = a_jobid
                   AND jt.name IN ('j_Application', 'j_License')
                   AND ad.country = 'UNITED STATES OF AMERICA';

            t_success := callwebservice ('GeocodeAddress', t_xml);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
        END;

        RETURN t_success;
    END addaddressbygeocoding;

    /*------------------------------------------------------------------------*
     *  AddAddressAtLocation() -- PUBLIC
     *------------------------------------------------------------------------*/
    FUNCTION addaddresspointatlocation (a_jobid udt_id, a_asofdate DATE)
        RETURN BOOLEAN
    IS
        t_licensetypes   VARCHAR2 (4000);
        t_xml            VARCHAR2 (4000);
        t_success        BOOLEAN;
    BEGIN
        t_licensetypes :=
            api.pkg_columnquery.VALUE (a_jobid, 'GISLicenseTypeCode');

        BEGIN
            SELECT    XMLELEMENT (
                          "x",
                          api.pkg_columnquery.VALUE (jo.jobid,
                                                     'OverriddenGeocodedX'))
                   || XMLELEMENT (
                          "y",
                          api.pkg_columnquery.VALUE (jo.jobid,
                                                     'OverriddenGeocodedY'))
                   || XMLELEMENT ("AppLicNumber", jo.externalfilenum)
                   || XMLELEMENT ("ObjectId", jo.jobid)
                   || XMLELEMENT ("LicenseType", t_licensetypes)
                   || XMLELEMENT ("JobType", jt.description)
              INTO t_xml
              FROM api.jobs  jo
                   JOIN api.jobtypes jt ON jo.jobtypeid = jt.jobtypeid
             WHERE     jo.jobid = a_jobid
                   AND jt.name IN ('j_Application', 'j_License');

            t_success := callwebservice ('AddAtLocation', t_xml);
        EXCEPTION
            WHEN OTHERS
            THEN
                t_success := FALSE;
                RAISE;
        END;

        RETURN t_success;
    END addaddresspointatlocation;

    /*------------------------------------------------------------------------*
     *  DeleteAddressPoint() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE deleteaddresspoint (a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid     udt_id;
        t_xml       VARCHAR2 (4000);
        t_success   BOOLEAN;
    BEGIN
        IF    api.pkg_constantquery.VALUE ('ISPRODUCTION') = 'Y'
           OR api.pkg_constantquery.VALUE ('SYNCGIS') = 'Y'
        THEN                         --Added SYNCGIS to sync GIS in Test Pawan
            t_jobid :=
                NVL (extension.pkg_common.jobidforprocess (a_objectid),
                     a_objectid);

            --api.pkg_Errors.RaiseError(-20000, 'In Delete: ' || t_JobId);
            BEGIN
                SELECT    XMLELEMENT ("PosseObjectId", t_jobid)
                       || XMLELEMENT ("JobType", jt.description)
                  INTO t_xml
                  FROM api.jobs  jo
                       JOIN api.jobtypes jt ON jo.jobtypeid = jt.jobtypeid
                 WHERE jo.jobid = t_jobid;

                t_success := callwebservice ('DeletePoint', t_xml);
            EXCEPTION
                WHEN OTHERS
                THEN
                    t_success := FALSE;
                    RAISE;
            END;

            IF NOT t_success
            THEN
                api.pkg_errors.raiseerror (
                    -20000,
                    'Error deleting address point in GIS');
            ELSE
                api.pkg_columnupdate.removevalue (t_jobid,
                                                  'GeolocationFailed');
                api.pkg_columnupdate.setvalue (t_jobid, 'IsGeocoded', 'N');
            END IF;
        END IF;
    END deleteaddresspoint;

    /*------------------------------------------------------------------------*
     *  UpdateAddressPoint() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE updateaddresspoint (a_objectid udt_id, a_asofdate DATE)
    IS
        t_jobid          udt_id;
        t_licensetypes   VARCHAR2 (4000);
        t_xml            VARCHAR2 (4000);
        t_success        BOOLEAN;
    BEGIN
        IF    api.pkg_constantquery.VALUE ('ISPRODUCTION') = 'Y'
           OR api.pkg_constantquery.VALUE ('SYNCGIS') = 'Y'
        THEN                        -- Added SYNCGIS to sync GIS in Test Pawan
            t_jobid :=
                NVL (extension.pkg_common.jobidforprocess (a_objectid),
                     a_objectid);
            t_licensetypes :=
                api.pkg_columnquery.VALUE (t_jobid, 'GISLicenseTypeCode');

            --api.pkg_Errors.RaiseError(-20000, 'test');
            --api.pkg_Errors.RaiseError(-20000, t_LicenseTypes);
            BEGIN
                SELECT    XMLELEMENT ("PosseObjectId", t_jobid)
                       || XMLELEMENT ("LicenseType", t_licensetypes)
                       || XMLELEMENT ("JobType", jt.description)
                  INTO t_xml
                  FROM api.jobs  jo
                       JOIN api.jobtypes jt ON jo.jobtypeid = jt.jobtypeid
                 WHERE jo.jobid = t_jobid;

                t_success := callwebservice ('UpdatePoint', t_xml);
            EXCEPTION
                WHEN OTHERS
                THEN
                    t_success := FALSE;
                    RAISE;
            END;
        END IF;
    END updateaddresspoint;

    /*------------------------------------------------------------------------*
     *  UpdatePointFromPLT() -- PUBLIC
     *------------------------------------------------------------------------*/
    /* procedure UpdatePointFromPLT(a_ObjectId                 udt_Id,
                                  a_AsOfDate                 date,
                                  a_ApplicationJobId         udt_Id
     ) is
       t_PendingGeocodeOperation       varchar2(10);
     begin
       t_PendingGeocodeOperation := api.pkg_ColumnQuery.Value(a_ApplicationJobId, 'PendingGeocodeOperation');

       if t_PendingGeocodeOperation = 'Add' then
         GeocodeAddress(a_ApplicationJobId, sysdate);
       elsif t_PendingGeocodeOperation = 'Update' then
         UpdateAddressPoint(a_ApplicationJobId, sysdate);
       elsif t_PendingGeocodeOperation = 'Delete' then
         DeleteAddressPoint(a_ApplicationJobId, sysdate);
       end if;
     end UpdatePointFromPLT; */


    PROCEDURE updatepointfromplt (a_objectid udt_id, a_asofdate DATE)
    IS
        t_pendinggeocodeoperation   VARCHAR2 (10);
    --t_objectid                  NUMBER;
    --t_applicationjobid          NUMBER;
    BEGIN
        /*  select gis.Objectid, gis.AppLicJobId
            into
            t_Objectid, t_ApplicationJobId
            from GISCalls gis
           where Objectid = a_Objectid
             and processed = 'N'; */

        FOR c IN (SELECT gis.objectid, gis.applicjobid, gis.seqnum
                    FROM sitespecific.giscalls gis
                   WHERE objectid = a_objectid AND processed = 'N')
        LOOP
            t_pendinggeocodeoperation :=
                api.pkg_columnquery.VALUE (c.applicjobid,
                                           'PendingGeocodeOperation');

            IF t_pendinggeocodeoperation = 'Add'
            THEN
                geocodeaddress (c.applicjobid, SYSDATE);
            ELSIF t_pendinggeocodeoperation = 'Update'
            THEN
                updateaddresspoint (c.applicjobid, SYSDATE);
            ELSIF t_pendinggeocodeoperation = 'Delete'
            THEN
                deleteaddresspoint (c.applicjobid, SYSDATE);
            END IF;

            UPDATE sitespecific.giscalls gis2
               SET processed = 'Y'
             WHERE gis2.seqnum = c.seqnum;
        END LOOP;
    END updatepointfromplt;



    /*------------------------------------------------------------------------*
     *  UpdatePointFromLT() -- PUBLIC
     *------------------------------------------------------------------------*/

    /*  procedure UpdatePointFromLT(a_ObjectId                 udt_Id,
                                  a_AsOfDate                 date,
                                  a_LicenseJobId             udt_Id
      ) is
        t_PendingGeocodeOperation       varchar2(10);
      begin
        t_PendingGeocodeOperation := api.pkg_ColumnQuery.Value(a_LicenseJobId, 'PendingGeocodeOperation');
    --api.pkg_Errors.RaiseError(-20000, 't_PendingGeocodeOperation: ' || t_PendingGeocodeOperation || ' a_LicenseJobId: ' || a_LicenseJobId);
        if t_PendingGeocodeOperation = 'Add' then
          GeocodeAddress(a_LicenseJobId, sysdate);
        elsif t_PendingGeocodeOperation = 'Update' then
          UpdateAddressPoint(a_LicenseJobId, sysdate);
        elsif t_PendingGeocodeOperation = 'Delete' then
          DeleteAddressPoint(a_LicenseJobId, sysdate);
        end if;
      end UpdatePointFromLT;  */

    PROCEDURE updatepointfromlt (a_objectid udt_id, a_asofdate DATE)
    IS
        t_pendinggeocodeoperation   VARCHAR2 (10);
    --t_objectid                  NUMBER;
    --t_licensejobid              NUMBER;
    BEGIN
        /*  select gis.Objectid, gis.AppLicJobId
             into
             t_Objectid, t_LicenseJobId
             from GISCalls gis
            where Objectid = a_Objectid
              and processed = 'N';  */

        FOR c IN (SELECT gis.objectid, gis.applicjobid, gis.seqnum
                    FROM sitespecific.giscalls gis
                   WHERE objectid = a_objectid AND processed = 'N')
        LOOP
            t_pendinggeocodeoperation :=
                api.pkg_columnquery.VALUE (c.applicjobid,
                                           'PendingGeocodeOperation');

            --api.pkg_Errors.RaiseError(-20000, 't_PendingGeocodeOperation: ' || t_PendingGeocodeOperation || ' a_LicenseJobId: ' || a_LicenseJobId);
            IF t_pendinggeocodeoperation = 'Add'
            THEN
                geocodeaddress (c.applicjobid, SYSDATE);
            ELSIF t_pendinggeocodeoperation = 'Update'
            THEN
                updateaddresspoint (c.applicjobid, SYSDATE);
            ELSIF t_pendinggeocodeoperation = 'Delete'
            THEN
                deleteaddresspoint (c.applicjobid, SYSDATE);
            END IF;

            UPDATE sitespecific.giscalls gis2
               SET processed = 'Y'
             WHERE gis2.seqnum = c.seqnum;
        END LOOP;
    END updatepointfromlt;


    /*------------------------------------------------------------------------*
     *  AddGeocodedAddressFromRel() -- PUBLIC
     *------------------------------------------------------------------------*/
    PROCEDURE addgeocodedaddressfromrel (a_relationshipid   udt_id,
                                         a_asofdate         DATE)
    IS
        t_pendinggeocodeoperation   VARCHAR2 (10);
        t_jobid                     udt_id;
    BEGIN
        SELECT jo.jobid
          INTO t_jobid
          FROM api.relationships  re
               JOIN api.jobs jo ON jo.jobid = re.toobjectid
               JOIN api.jobtypes jt ON jt.jobtypeid = jo.jobtypeid
         WHERE     re.relationshipid = a_relationshipid
               AND jt.name IN ('j_Application', 'j_License');

        -- Reset the Geocode flags
        api.pkg_columnupdate.setvalue (t_jobid, 'IsGeocoded', 'N');
        api.pkg_columnupdate.setvalue (t_jobid, 'GeolocationFailed', 'N');

        t_pendinggeocodeoperation :=
            api.pkg_columnquery.VALUE (t_jobid, 'PendingGeocodeOperation');

        --api.pkg_Errors.RaiseError(-20000, 't_PendingGeocodeOperation: ' || t_PendingGeocodeOperation || ' t_JobId: ' || t_JobId);

        -- Check to make sure the Add operation should be done.
        -- (Will not be done if no active lic types or Application not entered)
        IF t_pendinggeocodeoperation = 'Add'
        THEN
            geocodeaddress (t_jobid, SYSDATE);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            api.pkg_errors.raiseerror (
                -20000,
                'Error changing geocoded address: Application or License not found realted to this address.');
    END addgeocodedaddressfromrel;

    /*------------------------------------------------------------------------*
     * GetJobIdForDeletedRel() -- PUBLIC
     * Created by: Andy Patterson (CXUSA)
     * Created on: 12/29/2015
     * This procedure exists to work around a POSSE Product issue that is fixed in POSSE version 7.0
     * This procedure will autonomously grab the JobId from the Premise Address relationship that is being deleted
     *------------------------------------------------------------------------*/
    FUNCTION getjobidfordeletedrel (a_relationshipid udt_id)
        RETURN udt_id
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        t_jobid   udt_id;
    BEGIN
        t_jobid :=
            api.pkg_columnquery.numericvalue (a_relationshipid, 'JobId');

        IF t_jobid IS NULL
        THEN
            SELECT jo.jobid
              INTO t_jobid
              FROM api.relationships  re
                   JOIN api.jobs jo ON jo.jobid = re.toobjectid
                   JOIN api.jobtypes jt ON jt.jobtypeid = jo.jobtypeid
             WHERE     re.relationshipid = a_relationshipid
                   AND jt.name IN ('j_Application', 'j_License');
        END IF;

        RETURN t_jobid;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            api.pkg_errors.raiseerror (
                -20000,
                'Error changing geocoded address: Application or License not found related to this address.');
    END getjobidfordeletedrel;

    /*------------------------------------------------------------------------*
     * DeleteGeocodedAddressFromRel() -- PUBLIC
     * Modified by: Andy Patterson (CXUSA)
     * Modified on: 12/29/2015
     * Changed to get JobId autonomously by calling GetJobIdForDeletedRel
     *------------------------------------------------------------------------*/
    PROCEDURE deletegeocodedaddressfromrel (a_relationshipid   udt_id,
                                            a_asofdate         DATE)
    IS
        t_jobid   udt_id;
    BEGIN
        t_jobid := getjobidfordeletedrel (a_relationshipid);

        -- Delete the old point. If there is not a point, then the webservice will do nothing, so it is still safe
        deleteaddresspoint (t_jobid, SYSDATE);
    END deletegeocodedaddressfromrel;
END pkg_gis;

/


GRANT EXECUTE ON SITESPECIFIC.PKG_GIS TO EXTENSION;

GRANT EXECUTE ON SITESPECIFIC.PKG_GIS TO POSSESYS;
