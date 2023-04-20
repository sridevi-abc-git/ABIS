CREATE OR REPLACE PROCEDURE ABC.allocationreport_insert(a_startdate     DATE,
                                                        a_enddate       DATE)
AS
    -- **************************************************************************
    -- File:        ALLOCATIONREPORT_INSERT.PRC
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
    v_row   NUMBER := 1;
BEGIN
    dbms_output.put_line('1. Starting... ');

    DELETE FROM abc.allocation_licensefee_det;

    COMMIT;


    FOR c
        IN (SELECT NVL(
                       api.pkg_columnquery.numericvalue(ps.objectid,
                                                        'EarnedAmount'),
                       0)
                       amount,
                   api.pkg_columnquery.VALUE(ps.objectid, 'Converted')
                       converted,
                   api.pkg_columnquery.VALUE(ps.objectid, 'TransactionCode')
                       description,
                   api.pkg_columnquery.datevalue(f.objectid,
                                                 'RENExpirationDate')
                       expirationdate,
                   NVL(api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity'),
                       'UTR')
                       feeactivity,
                   api.pkg_columnquery.numericvalue(f.objectid, 'FeeId')
                       feeid,
                   api.pkg_columnquery.VALUE(ps.objectid, 'GallonageFeeCode')
                       gallonagerange,
                   api.pkg_columnquery.VALUE(ps.objectid, 'IsMaster')
                       ismaster,
                   api.pkg_columnquery.numericvalue(f.objectid, 'JobId')
                       jobid,
                   api.pkg_columnquery.VALUE(
                       (api.pkg_columnquery.numericvalue(f.objectid, 'JobId')),
                       'LicenseNumber')
                       licensenumber,
                   api.pkg_columnquery.VALUE(ps.objectid, 'LicenseTypeCode')
                       licensetypecode,
                   api.pkg_columnquery.VALUE(ps.objectid, 'MasterLT')
                       masterlt,
                   api.pkg_columnquery.VALUE(ps.objectid,
                                             'NumberOfMonthsLicensedFeeCode')
                       numberofmonthslicensed,
                   api.pkg_columnquery.VALUE(ps.objectid,
                                             'PopulationRangeFeeCode')
                       populationrange,
                   api.pkg_columnquery.VALUE(pt.objectid,
                                             'FeeScheduleDescriptionForGrid')
                       ptdescription,
                   api.pkg_columnquery.VALUE(ps.objectid, 'SecondaryCount')
                       secondarycount,
                   ft.transactionid
              FROM TABLE(
                       CAST(
                           api.pkg_simplesearch.castableobjectsbyindexrange(
                               'o_PaymentStatus',
                               'dup_CreatedDate',
                               TO_CHAR(a_startdate, 'YYYY-MM-DD'),
                               TO_CHAR(a_enddate, 'YYYY-MM-DD')) AS api.udt_objectlist))
                   ps
                   JOIN api.objects o ON o.objectid = ps.objectid
                   JOIN query.r_paymentstatuspaymenttrans pspt
                       ON pspt.paymentstatusobjectid = o.objectid
                   JOIN query.o_paymenttransactions pt
                       ON pt.objectid = pspt.paymenttransactionobjectid
                   JOIN api.feetransactions ft
                       ON ft.transactionid = pt.transactionid
                   JOIN api.fees af ON af.feeid = ft.feeid
                   JOIN query.o_fee f
                       ON f.objectid =
                          api.pkg_simplesearch.objectbyindex('o_fee',
                                                             'FeeId',
                                                             af.feeid)
                   JOIN api.relationships r
                       ON r.fromobjectid = f.objectid
                      AND r.endpointid IN
                              (api.pkg_configquery.endpointidforname(
                                   'o_Fee',
                                   'LicenseFeeSchedule'),
                               api.pkg_configquery.endpointidforname(
                                   'o_Fee',
                                   'MiscFeeSchedule'))
                   LEFT OUTER JOIN query.o_miscfeeschedule mfs
                       ON mfs.objectid = r.toobjectid
             WHERE (api.pkg_columnquery.VALUE(ps.objectid, 'Converted') = 'N' -- not converted
                AND (mfs.code IS NULL
                  OR mfs.code = 'UTR'))
                OR (api.pkg_columnquery.VALUE(ps.objectid, 'Converted') = 'Y' --when it is converted
                AND api.pkg_columnquery.VALUE(ps.objectid, 'FeeActivity') NOT IN
                        (SELECT m.code
                           FROM query.o_miscfeeschedule m
                          WHERE m.code <> 'UTR')))
    /*order by LicenseNumber,
             LicenseTypeCode,
             IsMaster,
             FeeActivity,
             api.pkg_ColumnQuery.DateValue(pt.ObjectId,
                                           'PaymentStatus'),
             Amount) */

    LOOP
        BEGIN
            dbms_output.put_line('Processing row ' || v_row);

            INSERT INTO abc.allocation_licensefee_det
                 VALUES (v_row,
                         c.amount,
                         c.converted,
                         c.description,
                         c.expirationdate,
                         c.feeactivity,
                         c.feeid,
                         c.gallonagerange,
                         c.ismaster,
                         c.jobid,
                         c.licensenumber,
                         c.licensetypecode,
                         c.masterlt,
                         c.numberofmonthslicensed,
                         c.populationrange,
                         c.ptdescription,
                         c.secondarycount,
                         c.transactionid,
                         TO_DATE('2016-07-01', 'YYYY-MM-DD'),
                         TO_DATE('2017-06-30', 'YYYY-MM-DD'));

            COMMIT;
            dbms_output.put_line(
                   '4. Porcessing record Allocation_LicenseFee_det: Tansaction id  '
                || c.transactionid);
            dbms_output.put_line('License number ' || c.licensenumber);
            dbms_output.put_line('Job Id ' || c.jobid);
            v_row   := v_row + 1;
            COMMIT;
        END;
    END LOOP;
END;
/
