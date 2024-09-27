CREATE OR REPLACE FUNCTION BIZMOD_API.CREATELICENSEAPP(a_packet       IN CLOB,
                                                       a_seq          IN NUMBER)
        RETURN CLOB
    IS
    -- ****************************************************************************
    -- File:        BIZMOD_API.CREATELICENSEAPP.PRC
    -- Author:      Timothy J. Lord
    --
    -- Purpose :
    --
    -- History:
    -------------------------------------------------------------------------------
    --             Date                         Comment
    --   1.1    05/02/2024  TJL  BIZ-15804  Initial Package Created
    --   2.0    07/18/2024  BN   BIZ-15804  Validation code added
    -- ****************************************************************************
    t_json_obj     json_object_t := json_object_t();
    t_json_data    json_object_t := json_object_t();
    t_process      VARCHAR2(40) := 'CREATELICENSEAPP';
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
    t_response     json_array_t := json_array_t();
    num             NUMBER;

    PROCEDURE validateInitialData(a_packet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
        
    for rec IN (
        SELECT * FROM JSON_TABLE(
                               a_packet,
                               '$'
                               COLUMNS(
                                   appType VARCHAR2(30)
                                       PATH '$.DATA.APPLICATIONTYPE',
                                   transferChangeType VARCHAR2(30)
                                       PATH '$.DATA.TRANSFERCHANGETYPE',
                                   multipleStockMember VARCHAR2(30)
                                       PATH '$.DATA.MULTIPLESTOCKMEMBERSHIPTRANS',
                                   priorityDrawAppl VARCHAR2(30)
                                       PATH '$.DATA.PRIORITYDRAWAPPLICATION',
                                   felony VARCHAR2(30)
                                        PATH '$.DATA.FELONY',
                                   dbaVal VARCHAR2(30)
                                        PATH '$.DATA.DBA',
                                   violate VARCHAR2(30)
                                        PATH '$.DATA.VIOLATION',
                                   licensePurPrice VARCHAR2(30)
                                        PATH '$.DATA.LICENSEPURCHASEPRICE',
                                   underConstruction VARCHAR2(30)
                                        PATH '$.DATA.UNDERCONSTRUCTION')))
        LOOP
        IF (rec.appType != 'Original' AND rec.appType != 'Transfer'  AND rec.appType != 'Change' )
        THEN
            t_response.append('Invalid application type (Original, Transfer, Change)');
        END IF;

        IF (rec.multipleStockMember != 'Y' AND rec.multipleStockMember != 'N')
        THEN
            t_response.append('Invalid multiple stock membership value (Y/N)');
        END IF;

        IF (rec.priorityDrawAppl != 'Y' AND rec.priorityDrawAppl != 'N')
        THEN
            t_response.append('Invalid priority draw application value (Y/N)');
        END IF;

        IF (rec.felony != 'Yes' AND rec.felony != 'No')
        THEN
            t_response.append('Invalid felony value (Yes/No)');
        END IF;
        IF (rec.violate != 'Yes' AND rec.violate != 'No')
        THEN
            t_response.append('Invalid violation value (Yes/No)');
        END IF;
        IF (LENGTH(rec.dbaVal) > 4000)
        THEN
            t_response.append('DBA exceeds character limit. (4000)');
        END IF;
        IF (LENGTH(rec.licensePurPrice) > 11)
        THEN
            t_response.append('License purchase price exceeds character limit (11).');
        END IF;
        END LOOP;

    END validateInitialData;


    PROCEDURE validateSecondaryLicense(secLiceDet IN CLOB, applicableSecLicense IN VARCHAR, t_response IN OUT json_array_t)
    IS
        delimiter VARCHAR(1) := ',';
        item VARCHAR2(255);
        secondaryLicenseFound Boolean := FALSE;
        licNum NUMBER;


    BEGIN
      
    for rec IN (
        SELECT * FROM JSON_TABLE(
                               secLiceDet,
                               '$[*]'
                               COLUMNS(
                                   secLicenseTypeCode VARCHAR2(6) PATH '$.LICENSETYPECODE',
                                   primaryCount VARCHAR2(6) PATH '$.PRIMARYCOUNT'
                                  )))
        LOOP
      --  DBMS_OUTPUT.put_line('secLicenseTypeCode : '|| rec.secLicenseTypeCode);
        secondaryLicenseFound := FALSE;

        IF (LENGTH(rec.secLicenseTypeCode) = 2)
        THEN


            FOR i IN 1..REGEXP_COUNT(applicableSecLicense, delimiter) + 1
            LOOP
                item := REGEXP_SUBSTR(applicableSecLicense, '[^'|| delimiter ||']+', 1, i);
               
                IF(TRIM(rec.secLicenseTypeCode) = TRIM(item))THEN
                    secondaryLicenseFound := TRUE;

                END IF;
            END LOOP;
            IF NOT secondaryLicenseFound
            THEN
                t_response.append('Invalid secondary license code');
            END IF;
        ELSE
            t_response.append('Invalid secondary License Code.');
        END IF;
        
        IF (LENGTH(rec.primaryCount) > 3)
        THEN
            t_response.append('Invalid Secondary License -- primary count value(3).');
        END IF;
        END LOOP;
        EXCEPTION
            WHEN VALUE_ERROR THEN
                t_response.append('Invalid Secondary License Code');

    END validateSecondaryLicense;

    PROCEDURE validateLicenceDetails(licenseDet IN CLOB, t_response IN OUT json_array_t)
    IS
        licenseFound Boolean := FALSE;
        licNum NUMBER;
        arrSize NUMBER;
    BEGIN

       -- DBMS_OUTPUT.put_line('licenseDet : '|| licenseDet);
        for rec IN (
        SELECT * FROM JSON_TABLE(
                               licenseDet,
                               '$[*]'
                               COLUMNS(
                                   licenseTypeCode VARCHAR2(10) PATH '$.LICENSETYPECODE',
                                   primaryCount VARCHAR2(6) PATH '$.PRIMARYCOUNT',
                                   gallonageRange VARCHAR2(30)  PATH '$.GALLONAGERANGE',
                                   seasonStartMonth VARCHAR2(30)  PATH '$.SEASONSTARTMONTH',
                                   isBranch VARCHAR2(3) PATH '$.ISBRANCH',
                                   masterLicense VARCHAR2(30) PATH '$.MASTERLICENSE',
                                   secondaryLicenseTypes CLOB
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES',
                                   numOfMonths NUMBER PATH '$.NUMBEROFMONTHSLICENSED' )))
        LOOP
            licNum := TO_NUMBER(rec.licenseTypeCode);
           
            IF (LENGTH(rec.licenseTypeCode) = 2)
            THEN
                -- fetching license information
                for licRec IN (
                        select *
                        from query.o_licenseTypeCategory
                        where licenseTypeCode = rec.licenseTypeCode)
                LOOP
                    licenseFound := TRUE;
                    IF (licRec.ISACTIVE = 'N')
                    THEN
                        t_response.append('Provide an Active License Code');
                        EXIT;
                    END IF;

                    IF(licRec.GALLONAGEAPPLIES = 'Y' AND rec.gallonageRange IS NULL )
                    THEN
                        t_response.append('Provide Gallon information for this license code.');
                    END IF;


                    IF(licRec.GALLONAGEAPPLIES = 'Y' AND rec.gallonageRange IS NOT NULL AND
                        (rec.gallonageRange != '0 TO 5K' AND rec.gallonageRange != '5K TO 20K' AND rec.gallonageRange != '20K TO 100K'
                        AND rec.gallonageRange != '100K TO 200K' AND rec.gallonageRange !=  '200K TO 1M'))
                    THEN
                        t_response.append('Provide valid gallonage range information.');
                    END IF;

                    IF (rec.licenseTypeCode = '86' AND rec.masterLicense IS NULL)
                    THEN
                           t_response.append('Provide master license information for this license code');
                    END IF;

                    IF(rec.isbranch != 'Y' AND rec.isbranch != 'N' )
                    THEN
                        t_response.append('Invalid is branch information (Y/N)');
                    END IF;


                    IF (rec.licenseTypeCode = '49' OR rec.licenseTypeCode = '59' OR rec.licenseTypeCode = '60')
                    THEN
                        IF (rec.numOfMonths IS NULL) THEN
                           t_response.append(' Provide number of months for this license code');
                        END IF;

                        IF (rec.seasonStartMonth IS NULL) THEN
                           t_response.append(' Provide season start month for this license code');
                        ELSE IF(rec.seasonStartMonth != 'JANUARY' AND rec.seasonStartMonth != 'FEBRUARY' AND rec.seasonStartMonth != 'MARCH'
                            AND rec.seasonStartMonth != 'APRIL' AND rec.seasonStartMonth != 'MAY' AND  rec.seasonStartMonth != 'JUNE' AND
                            rec.seasonStartMonth != 'JULY' AND rec.seasonStartMonth != 'AUGUST'AND rec.seasonStartMonth != 'SEPTEMBER'
                            AND rec.seasonStartMonth != 'OCTOBER' AND rec.seasonStartMonth != 'NOVEMBER' AND rec.seasonStartMonth != 'DECEMBER')
                        THEN
                            t_response.append('Provide valid season start month.');
                        END IF;
                        END IF;

                           EXIT;
                    END IF;

                    SELECT JSON_VALUE(rec.secondaryLicenseTypes, '$.size()')
                    INTO arrSize
                    FROM dual;

                    /*

                    IF(arrSize > licRec.MAXIMUMCOUNT)
                    THEN
                        t_response.append(' Maximum secondary licenses allowed for license number '|| rec.licenseTypeCode || ' is '|| licRec.MAXIMUMCOUNT) ;
                    END IF;

                    */

                    IF(licRec.SECONDARYLTSAPPLICABLE = 'Y' AND rec.secondaryLicenseTypes IS NOT NULL)
                    THEN
                    
                        validateSecondaryLicense(rec.secondaryLicenseTypes,licRec.SECONDARYLICENSETYPECODES, t_response);
                    END IF;


                END LOOP;

                IF NOT licenseFound
                THEN
                    t_response.append(' Invalid Primary License Code');
                END IF;                
            ELSE
                t_response.append(' Invalid Primary License Code.');
            END IF ;
            IF (LENGTH(rec.primaryCount) > 3)
            THEN
                    t_response.append('Invalid Primary License --  primary count value(3).');
            END IF;

        END LOOP;
        EXCEPTION
            WHEN VALUE_ERROR THEN
                t_response.append(' Invalid Primary License Code') ;
        RETURN;
    END validateLicenceDetails;

    PROCEDURE validateAddress(address IN CLOB,addrType IN VARCHAR, t_response IN OUT json_array_t)
    IS
        valueFound Boolean := FALSE;
        zip  NUMBER;
    BEGIN
        for rec IN (
        SELECT *  FROM JSON_TABLE(
                               address,
                               '$'
                               COLUMNS(
                                    addressLocation VARCHAR2(50) PATH '$.ADDRESSLOCATION',
                                    addressLine1 VARCHAR2(60) PATH '$.ADDRESSLINE1',
                                    addressLine2 VARCHAR2(60) PATH '$.ADDRESSLINE2',
                                    addressLine3 VARCHAR2(60) PATH '$.ADDRESSLINE3',
                                    phone VARCHAR2(20) PATH '$.PHONENUMBER',
                                    internationalPhone VARCHAR2(20) PATH '$.INTERNATIONALPHONENUMBER',
                                    fax VARCHAR2(20) PATH '$.FAXNUMBER',
                                   city VARCHAR2(200) PATH '$.USACITY',
                                   country VARCHAR2(30)  PATH '$.COUNTRY',
                                   zip VARCHAR2(30) PATH '$.ZIPCODE')))
        LOOP

            -- code zip length should be 5

            IF ((rec.addressLocation != 'Outside USA'))
            THEN

             IF (NOT (LENGTH(rec.zip) = 5 AND REGEXP_LIKE(rec.zip, '^\d{5}')) AND NOT (LENGTH(rec.zip) = 10 AND REGEXP_LIKE(rec.zip, '^\d{5}-\d{4}')) )
             THEN
                t_response.append(addrType || ' : Invalid Zip code.');
             END IF ;

             END IF;

             -- IF ( rec.phone IS NOT NULL AND (NOT (REGEXP_LIKE(rec.phone, '^[(]\d{3}[)]\d{3}-\d{4}'))) )
            --  IF ( (REGEXP_LIKE(rec.phone, '^\(?\d{3}\)?\d{3}-?\d{4}$')))
             IF (NOT (LENGTH(rec.phone) = 13  AND REGEXP_LIKE(rec.phone, '^[\(]\d{3}[\)]\d{3}-\d{4}')))
             THEN
                t_response.append(addrType || ' : Invalid phone number.Required format - (xxx)xxx-xxxx');
             END IF ;

             IF ( rec.fax IS NOT NULL AND (NOT (LENGTH(rec.fax) = 13 AND REGEXP_LIKE(rec.fax, '^[(]\d{3}[)]\d{3}-\d{4}'))) )
             THEN
                t_response.append(addrType || ' : Invalid fax number.Required format - (xxx)xxx-xxx.');
             END IF ;
             
             IF (LENGTH(rec.internationalPhone) > 30)
            THEN
                     t_response.append(addrType || ' : International Phone number exceeds the character limit.');
            END IF;

            IF(LENGTH(rec.addressLine1) > 50 )
            THEN
                t_response.append(addrType || ' : Address line 1 exceeds character limit (50).');
            END IF;
             IF(LENGTH(rec.addressLine2) > 50 )
            THEN
                t_response.append(addrType || ' : Address line 2 exceeds character limit (50).');
            END IF;
             IF(LENGTH(rec.addressLine3) > 50 )
            THEN
                t_response.append(addrType || ' : Address line 3 exceeds character limit (50).');
            END IF;
            
            IF(LENGTH(rec.city) > 40)
            THEN
                t_response.append(addrType || ' : City exceeds character limit.');
            END IF;

           
            -- if the state is California validate if the proper city is entered

            IF ((rec.addressLocation = 'In California'))
             THEN
                FOR cityRec IN (  SELECT attributevalue
                                  FROM possedata.objectcolumndata d
                                  WHERE columndefid = 328470
                                  ORDER BY 1)
                LOOP
                    IF (cityRec.attributevalue = UPPER(rec.city))
                    THEN
                        valueFound := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                IF NOT valueFound
                THEN
                    t_response.append(addrType || ' : Invalid California city');
                END IF;
             END IF;

            IF ((rec.addressLocation = 'Outside USA'))
            THEN
                IF(rec.country IS NULL)
                THEN
                    t_response.append(addrType || ' : Country should be provided for Outside USA address');
                ELSE
                    valueFound := FALSE;
                    FOR countryRec IN (  SELECT attributevalue
                                        FROM api.domainlistofvalues
                                       WHERE domainid = 301955
                                    ORDER BY 1)
                    LOOP
 
                        IF (countryRec.attributevalue = UPPER(rec.country))
                        THEN
                            valueFound := TRUE;
                            EXIT;
                        END IF;
                    END LOOP;

                    IF NOT valueFound
                    THEN
                        t_response.append(addrType || ' : Invalid country provided');
                    END IF;

                END IF;
             END IF;
        END LOOP;
        EXCEPTION
            WHEN VALUE_ERROR THEN
            t_response.append(addrType || ' : Invalid Zip code.');
        RETURN;
    END validateAddress;

    PROCEDURE validatePremisesAddressDetails(premisesAddDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
        for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   premisesAddDet,
                   '$'
                   COLUMNS(

                       outsideCityLimits VARCHAR2(100) PATH '$.OUTSIDECITYLIMITS',
                       highCrime VARCHAR2(100) PATH '$.HIGHCRIME',
                       cardRoomCasino VARCHAR2(100) PATH '$.CARDROOMCASINO',
                       noEvent VARCHAR2(100) PATH '$.NOEVENT',
                       eligibleForTransfer VARCHAR2(100) PATH '$.ELIGIBLEFORTRANSFER',
                       censusTract VARCHAR2(100) PATH '$.CENSUSTRACT',
                       censusSource VARCHAR2(100) PATH '$.CENSUSTRACTSOURCE',
                       geoCodeAddr VARCHAR2(100) PATH '$.GEOCODEADDRESSLINE1'                       
                       )))
            LOOP

            IF(rec.outsideCityLimits != 'Y' AND rec.outsideCityLimits != 'N')
            THEN
                t_response.append('Premises address : Invalid outside city limits value provided (Y/N)');
            END IF;
            IF(rec.highCrime != 'Y' AND rec.highCrime != 'N')
            THEN
                t_response.append('Premises address : Invalid high crime value provided (Y/N)');
            END IF;
            IF(rec.cardRoomCasino != 'Y' AND rec.cardRoomCasino != 'N')
            THEN
                t_response.append('Premises address : Invalid card room casino value provided (Y/N)');
            END IF;
            IF(rec.noEvent != 'Y' AND rec.noEvent != 'N')
            THEN
                t_response.append('Premises address : Invalid no event value provided (Y/N)');
            END IF;
            IF(rec.eligibleForTransfer != 'Y' AND rec.eligibleForTransfer != 'N')
            THEN
                t_response.append('Premises address : Invalid eligible for transfer value provided (Y/N)');
            END IF;
            IF(LENGTH(rec.censusTract) > 6)
            THEN
                t_response.append('Premises address : Census tract exceeds character limit(6).');
            END IF;
            IF(LENGTH(rec.censusSource) > 50)
            THEN
                t_response.append( 'Premises address : Census tract source exceeds character limit (50).');
            END IF;
            IF(LENGTH(rec.geoCodeAddr) > 40)
            THEN
                t_response.append('Premises address : Geocode Address exceeds character limit (40).');
            END IF;

            validateAddress(premisesAddDet,' Premises Address : ', t_response);

            END LOOP;
        RETURN;
    END validatePremisesAddressDetails;

    PROCEDURE validatePersonDetails(personDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN


          for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   personDet,
                   '$'
                   COLUMNS(
                       firstname VARCHAR2(200) PATH '$.FIRSTNAME',
                       middlename VARCHAR2(200) PATH '$.MIDDLENAME',
                       lastname VARCHAR2(200) PATH '$.LASTNAME',
                       suffix VARCHAR2(200) PATH '$.SUFFIX',
                       aliasName VARCHAR2(200) PATH '$.ALIASNAMES',
                       gender VARCHAR2(20) PATH '$.GENDER',
                       maritalStatus VARCHAR2(100) PATH '$.MARITALSTATUS',
                       address  CLOB
                           FORMAT JSON
                           PATH '$.ADDRESS'
                       )))
            LOOP

               --  DBMS_OUTPUT.put_line('lastname : '|| rec.lastname );
                IF (rec.lastname = '' OR rec.lastname IS NULL)
                THEN
                    t_response.append('aaaInvalid person last name in legal entities.');
                END IF;
                IF(LENGTH(rec.firstname) > 40)
                THEN
                    t_response.append('Person first name  exceeds character limit (40).');
                END IF;
                IF(LENGTH(rec.middlename) > 30)
                THEN
                    t_response.append('Person middle name exceeds character limit (30).');
                END IF;
                IF(LENGTH(rec.lastname) > 50)
                THEN
                    t_response.append('Person last name exceeds character limit (50).');
                END IF;
                IF(LENGTH(rec.suffix) > 20)
                THEN
                    t_response.append('Person suffix exceeds character limit (20).');
                END IF;
                IF(LENGTH(rec.aliasName) > 4000)
                THEN
                    t_response.append('Person Aliasname  exceeds character limit (4000).');
                END IF;

                IF (rec.gender != 'M' AND rec.gender != 'F')
                THEN
                    t_response.append('Invalid gender information (M/F)');
                END IF;
                IF (rec.maritalStatus != 'DIVORCED' AND  rec.maritalStatus != 'MARRIED'  AND rec.maritalStatus != 'SEPARATED'
                 AND rec.maritalStatus != 'REGISTERD DOMESTIC PARTNER'  AND rec.maritalStatus != 'SINGLE'  AND rec.maritalStatus != 'WIDOWED')
                THEN
                    t_response.append('Invalid marital status in legal entities.');
                END IF;

                validateAddress(rec.address,' Person', t_response);

            END LOOP;
        RETURN;
    END validatePersonDetails;

    PROCEDURE validateCompanyDetails(companyDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
          for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   companyDet,
                   '$'
                   COLUMNS(

                       companyname VARCHAR2(1000) PATH '$.COMPANYNAME',
                       companyStructure VARCHAR2(1000) PATH '$.COMPANYSTRUCTURE',
                       caSecStateNum VARCHAR2(1000) PATH '$.CASECRETARYOFSTATENUMBER',
                       federalIdNum VARCHAR2(1000) PATH '$.FEDERALEMPLOYERIDENTIFICATIONN',
                       address  CLOB
                           FORMAT JSON
                           PATH '$.ADDRESS'
                       )))
            LOOP

            IF(rec.companyname = '' OR rec.companyname IS NULL)
            THEN
                t_response.append('Invalid company name in legal entities.');
            END IF;

            IF(LENGTH(rec.companyname) > 250)
            THEN
                t_response.append('Legal Entity Company name exceeds character limit (250).');
            END IF;
            IF(LENGTH(rec.caSecStateNum) > 20)
            THEN
                t_response.append('Legal Entity CA Secretary State number exceeds character limit (20).');
            END IF;
            IF(LENGTH(rec.federalIdNum) > 6)
            THEN
                t_response.append('Legal Entity Federal employer identification number exceeds character limit (6).');
            END IF;
            
             IF(rec.companyStructure != 'CONSERVATORSHIP' AND  rec.companyStructure != 'CORPORATION'  AND rec.companyStructure != 'ESTATE'
             AND rec.companyStructure != 'LIMITED LIABILITY COMPANY'  AND rec.companyStructure != 'LIMITED PARTNERSHIP'
             AND rec.companyStructure != 'RECEIVORSHIP' AND rec.companyStructure != 'TRUST')
            THEN
                t_response.append('Invalid marital status in legal entities.');
            END IF;
            validateAddress(rec.address,' Company', t_response);

            END LOOP;
        RETURN;
    END validateCompanyDetails;

    PROCEDURE validateLegalEntitiesDetails(legalEntitiesDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
        for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   legalEntitiesDet,
                   '$'
                   COLUMNS(
                       legalEntityType VARCHAR2(4000) PATH '$.LEGALENTITYTYPE',
                       p12Type VARCHAR2(4000) PATH '$.P12TYPE',
                       ownertype VARCHAR2(4000) PATH '$.OWNERTYPE',
                       percentage NUMBER PATH '$.PERCENTAGEOFOWNERSHIP',
                       company  CLOB
                           FORMAT JSON
                           PATH '$.COMPANY',
                       person  CLOB
                           FORMAT JSON
                           PATH '$.PERSON',
                       legal_entities CLOB
                           FORMAT JSON
                           PATH '$.LEGALENTITIES')))
            LOOP

            IF (rec.legalEntityType != 'Entity' AND  rec.legalEntityType != 'Company' AND rec.legalEntityType != 'Person')
            THEN
                t_response.append('Invalid Legal entity type.');
            END IF;
            IF(LENGTH(rec.legalEntityType) > 4000)
            THEN
                t_response.append('Legal entity type  exceeds character limit (4000).');
            END IF;
            IF(LENGTH(rec.percentage) > 3)
            THEN
                t_response.append('Legal entity percentage ownership  exceeds character limit (3).');
            END IF;

            IF ((rec.p12Type IS NOT NULL) AND rec.p12Type != 'P12' AND rec.p12Type != 'P12A' )
            THEN
                t_response.append('Invalid P12 value of legal entity.');
            END IF;

             IF (rec.ownertype != 'GENERAL PARTNER' AND  rec.ownertype != 'LIMITED PARTNER'  AND rec.ownertype != 'MEMBER'
             AND rec.ownertype != 'PUBLICLY TRADED'  AND rec.ownertype != 'STOCK HOLDER'  AND rec.ownertype != 'FORMER CORPORATE NAME'
             AND rec.ownertype != 'FORMER MEMBER'  AND rec.ownertype != 'FORMER STOCKHOLDER')
            THEN
                t_response.append('Invalid owner type in legal entities.');
            END IF;

            IF (rec.company IS NOT NULL)
            THEN
     
                validateCompanyDetails(rec.company, t_response);
            END IF;

            IF (rec.person IS NOT NULL)
            THEN

                validatePersonDetails(rec.person, t_response);
            END IF;

            IF (rec.legal_entities IS NOT NULL)
            THEN
                validateLegalEntitiesDetails(rec.legal_entities, t_response);
            END IF;
            END LOOP;
        RETURN;
    END validateLegalEntitiesDetails;

    PROCEDURE validateAttorneyDetails(attorneyDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
          for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   attorneyDet,
                   '$'
                   COLUMNS(
                       TYPE VARCHAR2(400) PATH '$.TYPE',
                       firstname VARCHAR2(250) PATH '$.FIRSTNAME',
                       middlename VARCHAR2(250) PATH '$.MIDDLENAME',
                       lastname VARCHAR2(250) PATH '$.LASTNAME',
                       firmname VARCHAR2(4000) PATH '$.FIRMNAME',
                       email VARCHAR2(4000) PATH '$.EMAIL',
                       percentage NUMBER PATH '$.PERCENTAGE',
                       address  CLOB
                           FORMAT JSON
                           PATH '$.ADDRESS')))
            LOOP


           --DBMS_OUTPUT.put_line('last name : '|| rec.lastname);
            IF(rec.lastname = '' OR rec.lastname IS NULL)
            THEN
                t_response.append('Invalid last name for attorney');
            END IF;
            IF(LENGTH(rec.firstname) > 200)
            THEN
                t_response.append('Attorney first name  exceeds character limit (200).');
            END IF;
            IF(LENGTH(rec.middlename) > 200)
            THEN
                t_response.append('Attorney middle name exceeds character limit (200).');
            END IF;
            IF(LENGTH(rec.lastname) > 200)
            THEN
                t_response.append('Attorney last name exceeds character limit. (200)');
            END IF;
            IF(LENGTH(rec.firmname) > 500)
            THEN
                t_response.append('Attorney firm name exceeds character limit. (500)');
            END IF;
            IF(LENGTH(rec.email) > 100)
            THEN
                t_response.append('Attorney email exceeds character limit. (100)');
            END IF;

            validateAddress(rec.address,' Attorney', t_response);

            END LOOP;
        RETURN;
    END validateAttorneyDetails;

    PROCEDURE validateEscrowDetails(escrowDet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
          for rec IN (
          SELECT *
            FROM JSON_TABLE(
                   escrowDet,
                   '$'
                   COLUMNS(

                       companyName VARCHAR2(4000) PATH '$.ESCROWCOMPANYNAME',
                       address  CLOB
                           FORMAT JSON
                           PATH '$.ADDRESS')))
            LOOP

            IF(rec.companyName = '' OR rec.companyName IS NULL)
            THEN
                t_response.append('Invalid escrow company name');
            END IF;
            
            IF(LENGTH(rec.companyName) > 250)
            THEN
                t_response.append('Escrow company name exceeds character limit (250).');
            END IF;

            validateAddress(rec.address,' Escrow', t_response);

            END LOOP;
        RETURN;
    END validateEscrowDetails;



    PROCEDURE validateLicenseAppData(a_packet IN CLOB, t_response IN OUT json_array_t)
    IS

    BEGIN
           for rec IN (
        SELECT * FROM JSON_TABLE(
                               a_packet,
                               '$'
                               COLUMNS(
                                   packet_type VARCHAR2(1000) PATH '$.PACKET_TYPE',
                                   appType VARCHAR2(30)
                                       PATH '$.DATA.APPLICATIONTYPE',
                                   -- masterLicenseNum NUMBER PATH '$.DATA.MASTER_LICENSE',
                                   primaryLicenseType CLOB FORMAT JSON
                                       PATH '$.DATA.PRIMARYLICENSETYPES',
                                   premisesAddress CLOB FORMAT JSON
                                       PATH '$.DATA.PREMISESADDRESS',
                                   mailingAddress CLOB FORMAT JSON
                                       PATH '$.DATA.MAILINGADDRESS',
                                   attorney CLOB FORMAT JSON
                                        PATH '$.DATA.ATTORNEY',
                                   escrow CLOB FORMAT JSON
                                        PATH '$.DATA.ESCROW',
                                   legalEntities CLOB FORMAT JSON
                                        PATH '$.DATA.LEGALENTITIES')))
        LOOP
             validateInitialData(a_packet, t_response);

            IF (rec.primaryLicenseType IS NOT NULL)
            THEN
                validateLicenceDetails(rec.primaryLicenseType, t_response);
            END IF;


            IF (rec.premisesAddress IS NOT NULL)
            THEN

                validatePremisesAddressDetails(rec.premisesAddress, t_response);
            END IF;


            IF (rec.mailingAddress IS NOT NULL)
            THEN
                validateAddress(rec.mailingAddress,' Mailing Address', t_response);
            END IF;


            IF (rec.attorney IS NOT NULL)
            THEN
                validateAttorneyDetails(rec.attorney, t_response);
            END IF;
            IF (rec.escrow IS NOT NULL)
            THEN
                validateEscrowDetails(rec.escrow, t_response);
            END IF;

            IF (rec.legalEntities IS NOT NULL)
            THEN
                validateLegalEntitiesDetails(rec.legalEntities, t_response);
            END IF;

        END LOOP;
    END validateLicenseAppData;

BEGIN

        validateLicenseAppData(a_packet, t_response);

        IF (t_response.get_size() = 0)
        THEN
           
            bizmod_api.utl_licenseinfo.createjob(a_procedure => 'CREATELICENSEAPPJOB',
                                 a_description => 'Create License Application',
                                 a_argument1 => a_seq);

            t_json_data.put('MSGNO', '0');
            t_json_data.put('MSG', 'E-Services ' || t_process || ' Scheduled');
        ELSE
            t_msg :=
                'License Application Validation Failed: ('
                || REPLACE(t_response.TO_CLOB, '"', '')
                || ') ';
                -- || REPLACE(t_json_arr.TO_CLOB, '"', '');

            t_json_data.put('MSGNO', '17');
            t_json_data.put('MSG', t_msg);

            UPDATE bizmod_api.eservices_log_t
            SET err = t_msg
            WHERE seq = a_seq;
            num := SQL%rowcount;
            COMMIT;

        END IF;


    t_json_obj.put('PACKET_TYPE', 'MESSAGE');
    t_json_obj.put('DATA', t_json_data);
    utl_licenseinfo.clean(a_json => t_json_obj);

    RETURN t_json_obj.TO_CLOB;


EXCEPTION
    WHEN OTHERS
    THEN
        t_sqlerrm := SQLERRM;
        t_trace := DBMS_UTILITY.format_error_backtrace;
        t_msg := SUBSTR(t_sqlerrm || CHR(13) || t_trace, 1, 3990);


        UPDATE bizmod_api.eservices_log_t
           SET err = t_msg
         WHERE seq = a_seq;

        COMMIT;

        t_packet :=
            json_object(
                'PACKET_TYPE' VALUE 'MESSAGE',
                'DATA' VALUE
                    json_object('MSGNO' VALUE 5,
                                'MSG' VALUE 'Oracle Exception',
                                'EXCEPTION' VALUE t_sqlerrm));

        RETURN t_packet;
END;
/