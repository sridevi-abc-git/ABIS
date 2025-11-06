CREATE OR REPLACE FUNCTION BIZMOD_API.createlicenseapp(
    a_packet       IN CLOB,
    a_seq          IN NUMBER)
    RETURN CLOB
IS
    t_json_obj     json_object_t := json_object_t();
    t_json_data    json_object_t := json_object_t();
    t_process      VARCHAR2(40) := 'CREATELICENSEAPP';
    t_packet       CLOB;
    t_sqlerrm      VARCHAR2(4000);
    t_trace        VARCHAR2(4000);
    t_msg          VARCHAR2(4000 BYTE);
    t_response     json_array_t := json_array_t();
    num            NUMBER;

    PROCEDURE validateinitialdata(a_packet       IN     CLOB,
                                  t_response     IN OUT json_array_t)
    IS
        t_dupreqcount  NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_packet,
                           '$'
                           COLUMNS(
                               apptype
                                   VARCHAR2(30)
                                   PATH '$.DATA.APPLICATIONTYPE',
                               lspapplicationid
                                   VARCHAR2(30)
                                   PATH '$.DATA.LSPAPPLICATIONID',
                               transferchangetype
                                   VARCHAR2(30)
                                   PATH '$.DATA.TRANSFERCHANGETYPE',
                               multiplestockmember
                                   VARCHAR2(30)
                                   PATH '$.DATA.MULTIPLESTOCKMEMBERSHIPTRANS',
                               prioritydrawappl
                                   VARCHAR2(30)
                                   PATH '$.DATA.PRIORITYDRAWAPPLICATION',
                               felony VARCHAR2(30) PATH '$.DATA.FELONY',
                               dbaval VARCHAR2(30) PATH '$.DATA.DBA',
                               violate VARCHAR2(30) PATH '$.DATA.VIOLATION',
                               licensepurprice
                                   VARCHAR2(30)
                                   PATH '$.DATA.LICENSEPURCHASEPRICE',
                               underconstruction
                                   VARCHAR2(30)
                                   PATH '$.DATA.UNDERCONSTRUCTION')))
        LOOP
            IF (rec.apptype != 'Original'
            AND rec.apptype != 'Transfer'
            AND rec.apptype != 'Change')
            THEN
                t_response.append(
                    'Invalid application type (Original, Transfer, Change)');
            END IF;

            IF (rec.multiplestockmember != 'Y'
            AND rec.multiplestockmember != 'N')
            THEN
                t_response.append(
                    'Invalid multiple stock membership value (Y/N)');
            END IF;

            IF (rec.prioritydrawappl != 'Y'
            AND rec.prioritydrawappl != 'N')
            THEN
                t_response.append(
                    'Invalid priority draw application value (Y/N)');
            END IF;

            IF (rec.felony != 'Yes'
            AND rec.felony != 'No')
            THEN
                t_response.append('Invalid felony value (Yes/No)');
            END IF;

            IF (rec.violate != 'Yes'
            AND rec.violate != 'No')
            THEN
                t_response.append('Invalid violation value (Yes/No)');
            END IF;

            IF (LENGTH(rec.dbaval) > 4000)
            THEN
                t_response.append('DBA exceeds character limit. (4000)');
            END IF;

            IF (LENGTH(rec.licensepurprice) > 11)
            THEN
                t_response.append(
                    'License purchase price exceeds character limit (11).');
            END IF;
        END LOOP;
    END validateinitialdata;


    PROCEDURE validatesecondarylicense(seclicedet     IN     CLOB,
                                       applicableseclicense IN VARCHAR,
                                       t_response     IN OUT json_array_t)
    IS
        delimiter      VARCHAR(1) := ',';
        item           VARCHAR2(255);
        secondarylicensefound BOOLEAN := FALSE;
        licnum         NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           seclicedet,
                           '$[*]'
                           COLUMNS(
                               seclicensetypecode
                                   VARCHAR2(6)
                                   PATH '$.LICENSETYPECODE',
                               primarycount VARCHAR2(6) PATH '$.PRIMARYCOUNT')))
        LOOP
            --  DBMS_OUTPUT.put_line('secLicenseTypeCode : '|| rec.secLicenseTypeCode);
            secondarylicensefound := FALSE;

            --licNum := TO_NUMBER(rec.secLicenseTypeCode);
            IF (LENGTH(rec.seclicensetypecode) = 2)
            THEN
                FOR i
                    IN 1 .. REGEXP_COUNT(applicableseclicense, delimiter) + 1
                LOOP
                    item :=
                        REGEXP_SUBSTR(applicableseclicense,
                                      '[^' || delimiter || ']+',
                                      1,
                                      i);

                    --  DBMS_OUTPUT.put_line('item : '|| item);
                    IF (TRIM(rec.seclicensetypecode) = TRIM(item))
                    THEN
                        secondarylicensefound := TRUE;
                    --   DBMS_OUTPUT.put_line('inside if stamt : ');
                    END IF;
                END LOOP;

                IF NOT secondarylicensefound
                THEN
                    t_response.append('Invalid secondary license code');
                END IF;
            ELSE
                t_response.append('Invalid secondary License Code.');
            END IF;

            IF (LENGTH(rec.primarycount) > 3)
            THEN
                t_response.append(
                    'Invalid Secondary License -- primary count value(3).');
            END IF;
        END LOOP;
    EXCEPTION
        WHEN VALUE_ERROR
        THEN
            t_response.append('Invalid Secondary License Code');
    END validatesecondarylicense;

    PROCEDURE validatelicencedetails(licensedet     IN     CLOB,
                                     t_response     IN OUT json_array_t)
    IS
        licensefound   BOOLEAN := FALSE;
        licnum         NUMBER;
        arrsize        NUMBER;
        islicense86    BOOLEAN := FALSE;
        islicense20or21 BOOLEAN := FALSE;
        valid86licensenumber BOOLEAN := FALSE;
    BEGIN
        -- DBMS_OUTPUT.put_line('licenseDet : '|| licenseDet);
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           licensedet,
                           '$[*]'
                           COLUMNS(
                               licensetypecode
                                   VARCHAR2(10)
                                   PATH '$.LICENSETYPECODE',
                               primarycount VARCHAR2(6) PATH '$.PRIMARYCOUNT',
                               gallonagerange
                                   VARCHAR2(30)
                                   PATH '$.GALLONAGERANGE',
                               seasonstartmonth
                                   VARCHAR2(30)
                                   PATH '$.SEASONSTARTMONTH',
                               isbranch VARCHAR2(3) PATH '$.ISBRANCH',
                               masterlicense
                                   VARCHAR2(30)
                                   PATH '$.MASTERLICENSE',
                               secondarylicensetypes
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.SECONDARYLICENSETYPES',
                               numofmonths
                                   VARCHAR2(30)
                                   PATH '$.NUMBEROFMONTHSLICENSED')))
        LOOP
            licnum := TO_NUMBER(rec.licensetypecode);

            IF (LENGTH(rec.licensetypecode) = 2)
            THEN
                -- fetching license information
                FOR licrec IN (SELECT *
                                 FROM query.o_licensetypecategory
                                WHERE licensetypecode = rec.licensetypecode)
                LOOP
                    licensefound := TRUE;

                    IF (licrec.isactive = 'N')
                    THEN
                        t_response.append('Provide an Active License Code');
                        EXIT;
                    END IF;

                    IF (licrec.gallonageapplies = 'Y'
                    AND rec.gallonagerange IS NULL)
                    THEN
                        t_response.append(
                            'Provide Gallon information for this license code.');
                    END IF;


                    IF (licrec.gallonageapplies = 'Y'
                    AND rec.gallonagerange IS NOT NULL
                    AND (rec.gallonagerange != '0 TO 5K'
                     AND rec.gallonagerange != '5K TO 20K'
                     AND rec.gallonagerange != '20K TO 100K'
                     AND rec.gallonagerange != '100K TO 200K'
                     AND rec.gallonagerange != '200K TO 1M'))
                    THEN
                        t_response.append(
                            'Provide valid gallonage range information.');
                    END IF;

                    IF (rec.licensetypecode = '86')
                    THEN
                        islicense86 := TRUE;
                    END IF;

                    IF (rec.licensetypecode = '20'
                     OR rec.licensetypecode = '21')
                    THEN
                        islicense20or21 := TRUE;
                    END IF;

                    IF (rec.isbranch != 'Y'
                    AND rec.isbranch != 'N')
                    THEN
                        t_response.append(
                            'Invalid is branch information (Y/N)');
                    END IF;


                    IF (rec.licensetypecode = '49'
                     OR rec.licensetypecode = '59'
                     OR rec.licensetypecode = '60')
                    THEN
                        IF (rec.numofmonths IS NULL)
                        THEN
                            t_response.append(
                                ' Provide number of months for this license code');
                        END IF;

                        IF (rec.seasonstartmonth IS NULL)
                        THEN
                            t_response.append(
                                ' Provide season start month for this license code');
                        ELSE
                            IF (rec.seasonstartmonth != 'JANUARY'
                            AND rec.seasonstartmonth != 'FEBRUARY'
                            AND rec.seasonstartmonth != 'MARCH'
                            AND rec.seasonstartmonth != 'APRIL'
                            AND rec.seasonstartmonth != 'MAY'
                            AND rec.seasonstartmonth != 'JUNE'
                            AND rec.seasonstartmonth != 'JULY'
                            AND rec.seasonstartmonth != 'AUGUST'
                            AND rec.seasonstartmonth != 'SEPTEMBER'
                            AND rec.seasonstartmonth != 'OCTOBER'
                            AND rec.seasonstartmonth != 'NOVEMBER'
                            AND rec.seasonstartmonth != 'DECEMBER')
                            THEN
                                t_response.append(
                                    'Provide valid season start month.');
                            END IF;
                        END IF;

                        EXIT;
                    END IF;

                    SELECT json_value(rec.secondarylicensetypes, '$.size()')
                      INTO arrsize
                      FROM DUAL;

                    /*

                    IF(arrSize > licRec.MAXIMUMCOUNT)
                    THEN
                        t_response.append(' Maximum secondary licenses allowed for license number '|| rec.licenseTypeCode || ' is '|| licRec.MAXIMUMCOUNT) ;
                    END IF;

                    */

                    -- DBMS_OUTPUT.put_line('sec license value '|| rec.secondaryLicenseTypes);
                    -- DBMS_OUTPUT.put_line('sec type  '|| licRec.SECONDARYLTSAPPLICABLE);
                    IF (licrec.secondaryltsapplicable = 'Y'
                    AND rec.secondarylicensetypes IS NOT NULL)
                    THEN
                        --  DBMS_OUTPUT.put_line('sec license count 3333'|| arrSize);
                        validatesecondarylicense(
                            rec.secondarylicensetypes,
                            licrec.secondarylicensetypecodes,
                            t_response);
                    END IF;
                -- DBMS_OUTPUT.put_line('sec license count '|| arrSize);

                END LOOP;

                IF NOT licensefound
                THEN
                    t_response.append(' Invalid Primary License Code');
                END IF;
            ELSE
                t_response.append(' Invalid Primary License Code.');
            END IF;

            IF (LENGTH(rec.primarycount) > 3)
            THEN
                t_response.append(
                    'Invalid Primary License --  primary count value(3).');
            END IF;
        END LOOP;

        IF (islicense86
        AND (NOT islicense20or21))
        THEN
            t_response.append(
                ' Provide a valid second primary licence type(20,21) for license type 86.');
        END IF;
    EXCEPTION
        WHEN VALUE_ERROR
        THEN
            t_response.append(' Invalid Primary License Code');
            RETURN;
    END validatelicencedetails;

    PROCEDURE validateaddress(address        IN     CLOB,
                              addrtype       IN     VARCHAR,
                              t_response     IN OUT json_array_t)
    IS
        valuefound     BOOLEAN := FALSE;
        zip            NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           address,
                           '$'
                           COLUMNS(
                               addresslocation
                                   VARCHAR2(50)
                                   PATH '$.ADDRESSLOCATION',
                               addressline1
                                   VARCHAR2(60)
                                   PATH '$.ADDRESSLINE1',
                               addressline2
                                   VARCHAR2(60)
                                   PATH '$.ADDRESSLINE2',
                               addressline3
                                   VARCHAR2(60)
                                   PATH '$.ADDRESSLINE3',
                               phone VARCHAR2(20) PATH '$.PHONENUMBER',
                               internationalphone
                                   VARCHAR2(20)
                                   PATH '$.INTERNATIONALPHONENUMBER',
                               fax VARCHAR2(20) PATH '$.FAXNUMBER',
                               city VARCHAR2(200) PATH '$.USACITY',
                               country VARCHAR2(30) PATH '$.COUNTRY',
                               zip VARCHAR2(30) PATH '$.ZIPCODE')))
        LOOP
            -- code zip length should be 5

            IF ((rec.addresslocation != 'Outside USA'))
            THEN
                IF (NOT (LENGTH(rec.zip) = 5
                     AND REGEXP_LIKE(rec.zip, '^\d{5}'))
                AND NOT (LENGTH(rec.zip) = 10
                     AND REGEXP_LIKE(rec.zip, '^\d{5}-\d{4}')))
                THEN
                    t_response.append(addrtype || ' : Invalid Zip code.');
                END IF;
            END IF;

            -- IF ( rec.phone IS NOT NULL AND (NOT (REGEXP_LIKE(rec.phone, '^[(]\d{3}[)]\d{3}-\d{4}'))) )
            --  IF ( (REGEXP_LIKE(rec.phone, '^\(?\d{3}\)?\d{3}-?\d{4}$')))
            IF (NOT (LENGTH(rec.phone) = 13
                 AND REGEXP_LIKE(rec.phone, '^[\(]\d{3}[\)]\d{3}-\d{4}')))
            THEN
                t_response.append(
                    addrtype
                    || ' : Invalid phone number.Required format - (xxx)xxx-xxxx');
            END IF;

            IF (rec.fax IS NOT NULL
            AND (NOT (LENGTH(rec.fax) = 13
                  AND REGEXP_LIKE(rec.fax, '^[(]\d{3}[)]\d{3}-\d{4}'))))
            THEN
                t_response.append(
                    addrtype
                    || ' : Invalid fax number.Required format - (xxx)xxx-xxx.');
            END IF;

            IF (LENGTH(rec.internationalphone) > 30)
            THEN
                t_response.append(
                    addrtype
                    || ' : International Phone number exceeds the character limit.');
            END IF;

            IF (LENGTH(rec.addressline1) > 50)
            THEN
                t_response.append(
                    addrtype
                    || ' : Address line 1 exceeds character limit (50).');
            END IF;

            IF (LENGTH(rec.addressline2) > 50)
            THEN
                t_response.append(
                    addrtype
                    || ' : Address line 2 exceeds character limit (50).');
            END IF;

            IF (LENGTH(rec.addressline3) > 50)
            THEN
                t_response.append(
                    addrtype
                    || ' : Address line 3 exceeds character limit (50).');
            END IF;

            IF (LENGTH(rec.city) > 40)
            THEN
                t_response.append(
                    addrtype || ' : City exceeds character limit.');
            END IF;

            -- DBMS_OUTPUT.put_line('t_response after : '|| t_response );

            -- if the state is California validate if the proper city is entered

            IF ((rec.addresslocation = 'In California'))
            THEN
                FOR cityrec IN (  SELECT attributevalue
                                    FROM possedata.objectcolumndata d
                                   WHERE columndefid = 328470
                                ORDER BY 1)
                LOOP
                    IF (cityrec.attributevalue = UPPER(rec.city))
                    THEN
                        valuefound := TRUE;
                        EXIT;
                    END IF;
                END LOOP;

                IF NOT valuefound
                THEN
                    t_response.append(
                        addrtype || ' : Invalid California city');
                END IF;
            END IF;

            IF ((rec.addresslocation = 'Outside USA'))
            THEN
                IF (rec.country IS NULL)
                THEN
                    t_response.append(
                        addrtype
                        || ' : Country should be provided for Outside USA address');
                ELSE
                    valuefound := FALSE;

                    FOR countryrec IN (  SELECT attributevalue
                                           FROM api.domainlistofvalues
                                          WHERE domainid = 301955
                                       ORDER BY 1)
                    LOOP
                        -- DBMS_OUTPUT.put_line('countryRec.attributevalue : '|| countryRec.attributevalue );
                        -- DBMS_OUTPUT.put_line('rec.country : '|| rec.country );
                        IF (countryrec.attributevalue = UPPER(rec.country))
                        THEN
                            valuefound := TRUE;
                            EXIT;
                        END IF;
                    END LOOP;

                    IF NOT valuefound
                    THEN
                        t_response.append(
                            addrtype || ' : Invalid country provided');
                    END IF;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN VALUE_ERROR
        THEN
            t_response.append(addrtype || ' : Invalid Zip code.');
            RETURN;
    END validateaddress;

    PROCEDURE validatepremisesaddressdetails(
        premisesadddet IN     CLOB,
        t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           premisesadddet,
                           '$'
                           COLUMNS(
                               outsidecitylimits
                                   VARCHAR2(100)
                                   PATH '$.OUTSIDECITYLIMITS',
                               highcrime VARCHAR2(100) PATH '$.HIGHCRIME',
                               cardroomcasino
                                   VARCHAR2(100)
                                   PATH '$.CARDROOMCASINO',
                               noevent VARCHAR2(100) PATH '$.NOEVENT',
                               eligiblefortransfer
                                   VARCHAR2(100)
                                   PATH '$.ELIGIBLEFORTRANSFER',
                               censustract VARCHAR2(100) PATH '$.CENSUSTRACT',
                               censussource
                                   VARCHAR2(100)
                                   PATH '$.CENSUSTRACTSOURCE',
                               geocodeaddr
                                   VARCHAR2(100)
                                   PATH '$.GEOCODEADDRESSLINE1')))
        LOOP
            IF (rec.outsidecitylimits != 'Y'
            AND rec.outsidecitylimits != 'N')
            THEN
                t_response.append(
                    'Premises address : Invalid outside city limits value provided (Y/N)');
            END IF;

            IF (rec.highcrime != 'Y'
            AND rec.highcrime != 'N')
            THEN
                t_response.append(
                    'Premises address : Invalid high crime value provided (Y/N)');
            END IF;

            IF (rec.cardroomcasino != 'Y'
            AND rec.cardroomcasino != 'N')
            THEN
                t_response.append(
                    'Premises address : Invalid card room casino value provided (Y/N)');
            END IF;

            IF (rec.noevent != 'Y'
            AND rec.noevent != 'N')
            THEN
                t_response.append(
                    'Premises address : Invalid no event value provided (Y/N)');
            END IF;

            IF (rec.eligiblefortransfer != 'Y'
            AND rec.eligiblefortransfer != 'N')
            THEN
                t_response.append(
                    'Premises address : Invalid eligible for transfer value provided (Y/N)');
            END IF;

            IF (LENGTH(rec.censustract) > 9)
            THEN
                t_response.append(
                    'Premises address : Census tract exceeds character limit(6).');
            END IF;

            IF (LENGTH(rec.censussource) > 50)
            THEN
                t_response.append(
                    'Premises address : Census tract source exceeds character limit (50).');
            END IF;

            IF (LENGTH(rec.geocodeaddr) > 50)
            THEN
                t_response.append(
                    'Premises address : Geocode Address exceeds character limit (40).');
            END IF;

            validateaddress(premisesadddet,
                            ' Premises Address : ',
                            t_response);
        END LOOP;

        RETURN;
    END validatepremisesaddressdetails;

    PROCEDURE validatepersondetails(persondet      IN     CLOB,
                                    t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           persondet,
                           '$'
                           COLUMNS(
                               firstname VARCHAR2(200) PATH '$.FIRSTNAME',
                               middlename VARCHAR2(200) PATH '$.MIDDLENAME',
                               lastname VARCHAR2(200) PATH '$.LASTNAME',
                               suffix VARCHAR2(200) PATH '$.SUFFIX',
                               aliasname VARCHAR2(200) PATH '$.ALIASNAMES',
                               gender VARCHAR2(20) PATH '$.GENDER',
                               maritalstatus
                                   VARCHAR2(100)
                                   PATH '$.MARITALSTATUS',
                               address CLOB FORMAT JSON PATH '$.ADDRESS')))
        LOOP
            IF (LENGTH(rec.firstname) > 40)
            THEN
                t_response.append(
                    'Person first name exceeds character limit (40).');
            END IF;

            IF (LENGTH(rec.middlename) > 30)
            THEN
                t_response.append(
                    'Person middle name exceeds character limit (30).');
            END IF;

            IF (LENGTH(rec.lastname) > 50)
            THEN
                t_response.append(
                    'Person last name exceeds character limit (50).');
            END IF;

            IF (LENGTH(rec.suffix) > 20)
            THEN
                t_response.append(
                    'Person suffix exceeds character limit (20).');
            END IF;

            IF (LENGTH(rec.aliasname) > 4000)
            THEN
                t_response.append(
                    'Person Aliasname  exceeds character limit (4000).');
            END IF;

            /*
                            IF (rec.gender IS NOT NULL AND (rec.gender != 'M' AND rec.gender != 'F'))
                            THEN
                                t_response.append('Invalid gender information (M/F)');
                            END IF;

                            IF ( rec.maritalStatus IS NOT NULL AND rec.maritalStatus != 'DIVORCED' AND  rec.maritalStatus != 'MARRIED'  AND rec.maritalStatus != 'SEPARATED'
                             AND rec.maritalStatus != 'REGISTERD DOMESTIC PARTNER'  AND rec.maritalStatus != 'SINGLE'  AND rec.maritalStatus != 'WIDOWED')
                            THEN
                                t_response.append('Invalid marital status in legal entities.');
                            END IF;
                            */

            validateaddress(rec.address, ' Person', t_response);
        END LOOP;

        RETURN;
    END validatepersondetails;

    PROCEDURE validatecompanydetails(companydet     IN     CLOB,
                                     t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           companydet,
                           '$'
                           COLUMNS(
                               companyname
                                   VARCHAR2(1000)
                                   PATH '$.COMPANYNAME',
                               companystructure
                                   VARCHAR2(1000)
                                   PATH '$.COMPANYSTRUCTURE',
                               casecstatenum
                                   VARCHAR2(1000)
                                   PATH '$.CASECRETARYOFSTATENUMBER',
                               federalidnum
                                   VARCHAR2(1000)
                                   PATH '$.FEDERALEMPLOYERIDENTIFICATIONN',
                               ownertype VARCHAR2(4000) PATH '$.OWNERTYPE',
                               title VARCHAR2(4000) PATH '$.TITLE',
                               address CLOB FORMAT JSON PATH '$.ADDRESS')))
        LOOP
            /*
                        IF(rec.companyname = '' OR rec.companyname IS NULL)
                        THEN
                            t_response.append('Invalid company name in legal entities.');
                        END IF;*/


            IF (LENGTH(rec.companyname) > 250)
            THEN
                t_response.append(
                    'Legal Entity Company name exceeds character limit (250).');
            END IF;

            IF (LENGTH(rec.casecstatenum) > 20)
            THEN
                t_response.append(
                    'Legal Entity CA Secretary State number exceeds character limit (20).');
            END IF;

            IF (NOT (LENGTH(rec.federalidnum) = 9
                 AND REGEXP_LIKE(rec.federalidnum, '^\d{9}')))
            THEN
                t_response.append(
                    'Invalid Legal Entity Federal employer identification number provided.');
            END IF;

            /*
           IF(LENGTH(rec.federalIdNum) > 10)
           THEN
               t_response.append('Legal Entity Federal employer identification number exceeds character limit (6).');
           END IF;
           */

            IF (rec.companystructure != 'CONSERVATORSHIP'
            AND rec.companystructure != 'CORPORATION'
            AND rec.companystructure != 'ESTATE'
            AND rec.companystructure != 'LIMITED LIABILITY COMPANY'
            AND rec.companystructure != 'LIMITED PARTNERSHIP'
            AND rec.companystructure != 'RECEIVORSHIP'
            AND rec.companystructure != 'TRUST')
            THEN
                t_response.append(
                    'Invalid marital status in legal entities.');
            END IF;

            IF (rec.ownertype != 'GENERAL PARTNER'
            AND rec.ownertype != 'LIMITED PARTNER'
            AND rec.ownertype != 'MEMBER'
            AND rec.ownertype != 'PUBLICLY TRADED'
            AND rec.ownertype != 'STOCKHOLDER'
            AND rec.ownertype != 'FORMER CORPORATE NAME'
            AND rec.ownertype != 'FORMER MEMBER'
            AND rec.ownertype != 'FORMER STOCKHOLDER')
            THEN
                t_response.append('Invalid owner type in legal entities.');
            END IF;

            validateaddress(rec.address, ' Company', t_response);
        END LOOP;

        RETURN;
    END validatecompanydetails;

    PROCEDURE validatelegalentitiesdetails(
        legalentitiesdet IN   CLOB,
        t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           legalentitiesdet,
                           '$'
                           COLUMNS(
                               legalentitytype
                                   VARCHAR2(4000)
                                   PATH '$.LEGALENTITYTYPE',
                               p12type VARCHAR2(4000) PATH '$.P12TYPE',
                               percentage
                                   NUMBER
                                   PATH '$.PERCENTAGEOFOWNERSHIP',
                               company CLOB FORMAT JSON PATH '$.COMPANY',
                               person CLOB FORMAT JSON PATH '$.PERSON',
                               legal_entities
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.LEGALENTITIES')))
        LOOP
            IF (rec.legalentitytype != 'Entity'
            AND rec.legalentitytype != 'Company'
            AND rec.legalentitytype != 'Person')
            THEN
                t_response.append('Invalid Legal entity type.');
            END IF;

            IF (LENGTH(rec.legalentitytype) > 4000)
            THEN
                t_response.append(
                    'Legal entity type  exceeds character limit (4000).');
            END IF;

            IF (LENGTH(rec.percentage) > 3)
            THEN
                t_response.append(
                    'Legal entity percentage ownership  exceeds character limit (3).');
            END IF;

            IF ((rec.p12type IS NOT NULL)
            AND rec.p12type != 'P12'
            AND rec.p12type != 'P12A')
            THEN
                t_response.append('Invalid P12 value of legal entity.');
            END IF;

            -- DBMS_OUTPUT.put_line('company : '|| rec.company);
            IF (rec.company IS NOT NULL)
            THEN
                -- DBMS_OUTPUT.put_line('inside comp : ');
                validatecompanydetails(rec.company, t_response);
            END IF;

            IF (rec.person IS NOT NULL)
            THEN
                validatepersondetails(rec.person, t_response);
            END IF;

            IF (rec.legal_entities IS NOT NULL)
            THEN
                validatelegalentitiesdetails(rec.legal_entities, t_response);
            END IF;
        END LOOP;

        RETURN;
    END validatelegalentitiesdetails;

    PROCEDURE validateattorneydetails(attorneydet    IN     CLOB,
                                      t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           attorneydet,
                           '$'
                           COLUMNS(
                               TYPE VARCHAR2(400) PATH '$.TYPE',
                               firstname VARCHAR2(250) PATH '$.FIRSTNAME',
                               middlename VARCHAR2(250) PATH '$.MIDDLENAME',
                               lastname VARCHAR2(250) PATH '$.LASTNAME',
                               firmname VARCHAR2(4000) PATH '$.FIRMNAME',
                               email VARCHAR2(4000) PATH '$.EMAIL',
                               percentage NUMBER PATH '$.PERCENTAGE',
                               address CLOB FORMAT JSON PATH '$.ADDRESS')))
        LOOP
            --DBMS_OUTPUT.put_line('last name : '|| rec.lastname);
            IF (rec.lastname = ''
             OR rec.lastname IS NULL)
            THEN
                t_response.append('Invalid last name for attorney');
            END IF;

            IF (LENGTH(rec.firstname) > 200)
            THEN
                t_response.append(
                    'Attorney first name  exceeds character limit (200).');
            END IF;

            IF (LENGTH(rec.middlename) > 200)
            THEN
                t_response.append(
                    'Attorney middle name exceeds character limit (200).');
            END IF;

            IF (LENGTH(rec.lastname) > 200)
            THEN
                t_response.append(
                    'Attorney last name exceeds character limit. (200)');
            END IF;

            IF (LENGTH(rec.firmname) > 500)
            THEN
                t_response.append(
                    'Attorney firm name exceeds character limit. (500)');
            END IF;

            IF (LENGTH(rec.email) > 100)
            THEN
                t_response.append(
                    'Attorney email exceeds character limit. (100)');
            END IF;

            validateaddress(rec.address, ' Attorney', t_response);
        END LOOP;

        RETURN;
    END validateattorneydetails;

    PROCEDURE validateescrowdetails(escrowdet      IN     CLOB,
                                    t_response     IN OUT json_array_t)
    IS
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           escrowdet,
                           '$'
                           COLUMNS(
                               companyname
                                   VARCHAR2(4000)
                                   PATH '$.ESCROWCOMPANYNAME',
                               address CLOB FORMAT JSON PATH '$.ADDRESS')))
        LOOP
            IF (rec.companyname = ''
             OR rec.companyname IS NULL)
            THEN
                t_response.append('Invalid escrow company name');
            END IF;

            IF (LENGTH(rec.companyname) > 250)
            THEN
                t_response.append(
                    'Escrow company name exceeds character limit (250).');
            END IF;

            validateaddress(rec.address, ' Escrow', t_response);
        END LOOP;

        RETURN;
    END validateescrowdetails;



    PROCEDURE validatelicenseappdata(a_packet       IN     CLOB,
                                     t_response     IN OUT json_array_t)
    IS
        t_count        NUMBER;
    BEGIN
        FOR rec
            IN (SELECT *
                  FROM JSON_TABLE(
                           a_packet,
                           '$'
                           COLUMNS(
                               packet_type
                                   VARCHAR2(1000)
                                   PATH '$.PACKET_TYPE',
                               apptype
                                   VARCHAR2(30)
                                   PATH '$.DATA.APPLICATIONTYPE',
                               lspappid
                                   VARCHAR2(30)
                                   PATH '$.DATA.LSPAPPLICATIONID',
                               -- masterLicenseNum NUMBER PATH '$.DATA.MASTER_LICENSE',
                               primarylicensetype
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.DATA.PRIMARYLICENSETYPES',
                               premisesaddress
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.DATA.PREMISESADDRESS',
                               mailingaddress
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.DATA.MAILINGADDRESS',
                               attorney
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.DATA.ATTORNEY',
                               escrow CLOB FORMAT JSON PATH '$.DATA.ESCROW',
                               legalentities
                                   CLOB
                                   FORMAT JSON
                                   PATH '$.DATA.LEGALENTITIES')))
        LOOP
            SELECT COUNT(*)
              INTO t_count
              FROM bizmod_api.license_app_t la
             WHERE la.lspid = rec.lspappid;

            IF (t_count > 0)
            THEN
                t_response.append(
                    'Duplicate LSP Appication Id: ' || rec.lspappid);
            END IF;

            validateinitialdata(a_packet, t_response);

            IF (rec.primarylicensetype IS NOT NULL)
            THEN
                validatelicencedetails(rec.primarylicensetype, t_response);
            END IF;


            IF (rec.premisesaddress IS NOT NULL)
            THEN
                validatepremisesaddressdetails(rec.premisesaddress,
                                               t_response);
            END IF;


            IF (rec.mailingaddress IS NOT NULL)
            THEN
                validateaddress(rec.mailingaddress,
                                ' Mailing Address',
                                t_response);
            END IF;


            IF (rec.attorney IS NOT NULL)
            THEN
                validateattorneydetails(rec.attorney, t_response);
            END IF;

            IF (rec.escrow IS NOT NULL)
            THEN
                validateescrowdetails(rec.escrow, t_response);
            END IF;

            IF (rec.legalentities IS NOT NULL)
            THEN
                validatelegalentitiesdetails(rec.legalentities, t_response);
            END IF;
        END LOOP;
    END validatelicenseappdata;
BEGIN
    validatelicenseappdata(a_packet, t_response);

    IF (t_response.get_size() = 0)
    THEN
        bizmod_api.utl_licenseinfo.createjob(
            a_procedure => 'CREATELICENSEAPPJOB',
            a_application_id =>
                json_value(a_packet,
                           '$.DATA.LSPAPPLICATIONID'
                           RETURNING NUMBER),
            a_parameters =>
                bizmod_api.job_prameters_tbl(
                    a_seq,
                    SYSDATE));

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

        num := SQL%ROWCOUNT;
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
