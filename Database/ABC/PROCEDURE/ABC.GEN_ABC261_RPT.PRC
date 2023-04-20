CREATE OR REPLACE PROCEDURE ABC.GEN_ABC261_RPT  --(P_ISSUEDATE date)
AS

t_ptfeeobjectlist   api.udt_objectlist;
t_count             number;

cursor c_lictype is
SELECT L.JOBID, -- LT.JOBID
L.LICENSENUMBER FILENUM, UPPER(L.LICENSEE) LICENSEE, L.STATUSNAME STATUS,
L.BASEFILEOFFICECODECORRAL DISTRICT, LT.LICENSETYPECODE LTCODE, LT.STATUSNAME LTSTATUS,
to_date(to_char(LT.EXPIRATIONDATE,'mm/dd/yyyy'),'mm/dd/yyyy') LTEXPDATE,
LT.GALLONAGERANGEFEECODE LTFEECODE,
to_date(to_char(NVL(LT.ISSUEDATE,JSC.EFFECTIVESTARTDATE),'mm/dd/yyyy'),'mm/dd/yyyy') LTISSDATE,
AD1.GEOCODE PREMGEO, INITCAP(AD1.ADDRESSLINE1) PREMADDR1, INITCAP(AD1.ADDRESSLINE2) PREMADDR2,
INITCAP(AD1.USACITY) PREMCITY, AD1.USASTATECODE PREMSTATE, AD1.ZIPCODE PREMZIP,
INITCAP(AD2.ADDRESSLINE1) MAILADDR1, INITCAP(AD2.ADDRESSLINE2) MAILADDR2, INITCAP(AD2.USACITY) MAILCITY,
AD2.USASTATECODE MAILSTATE, AD2.ZIPCODE MAILZIP
FROM QUERY.J_LICENSE L
JOIN QUERY.R_LICENSELICENSETYPE RLT             ON RLT.LICENSEJOBID = L.JOBID
JOIN QUERY.J_LICENSETYPE LT                     ON LT.JOBID = RLT.LICENSETYPEJOBID
JOIN API.JOBSTATUSES JS1                        ON JS1.JOBTYPEID = L.JOBTYPEID
     AND JS1.STATUSID = L.STATUSID AND JS1.STATUSTYPE IN ('O','I')
JOIN API.JOBSTATUSES JS2                        ON JS2.JOBTYPEID = LT.JOBTYPEID
     AND JS2.STATUSID = LT.STATUSID AND JS2.STATUSTYPE IN ('O','I')
LEFT OUTER JOIN EXTENSION.JOBSTATUSCHANGE_T JSC ON JSC.JOBID = LT.JOBID AND JSC.MOSTRECENT = 'Y'
LEFT OUTER JOIN QUERY.R_LICENSEADDRPREMISES RPA ON RPA.LICENSEJOBID = L.JOBID
LEFT OUTER JOIN QUERY.O_ADDRESS AD1             ON AD1.OBJECTID = RPA.PREMISESOBJECTID
LEFT OUTER JOIN QUERY.R_LICENSEADDRMAILING RMA  ON RMA.LICENSEJOBID = L.JOBID
LEFT OUTER JOIN QUERY.O_ADDRESS AD2             ON AD2.OBJECTID = RMA.MAOBJECTID
WHERE LT.LICENSETYPECODE IN ('02','22')
AND NVL(LT.ISSUEDATE,JSC.EFFECTIVESTARTDATE) <= current_date --:A_ISSUEDATE
ORDER BY FILENUM, LTCODE;

c_lictype_rec   c_lictype%rowtype;

begin

  delete from ABC.ABC261_RPT;

  --loop through all License types.
  open c_lictype;
  loop
    fetch c_lictype into c_lictype_rec;
    exit when c_lictype%notfound;

    select count(*)
    into t_count
    from ABC.ABC261_RPT
    where Filenum = c_Lictype_Rec.Filenum
    and   Ltcode = c_Lictype_Rec.Ltcode;

    if t_count = 0 then
        insert into ABC.ABC261_RPT
        (Filenum, Licensee, Status, District,
         Ltcode, Ltstatus, Ltexpdate, Ltfeecode,
         Ltissdate, Premgeo, Premaddr1, Premaddr2,
         Premcity, Premstate, Premzip, Mailaddr1,
         Mailaddr2, Mailcity, Mailstate, Mailzip)
        values
        (c_Lictype_Rec.Filenum, c_Lictype_Rec.Licensee, c_Lictype_Rec.Status, c_Lictype_Rec.District,
         c_Lictype_Rec.Ltcode, c_Lictype_Rec.Ltstatus, c_Lictype_Rec.Ltexpdate, c_Lictype_Rec.Ltfeecode,
         c_Lictype_Rec.Ltissdate, c_Lictype_Rec.Premgeo, c_Lictype_Rec.Premaddr1, c_Lictype_Rec.Premaddr2,
         c_Lictype_Rec.Premcity, c_Lictype_Rec.Premstate, c_Lictype_Rec.Premzip, c_Lictype_Rec.Mailaddr1,
         c_Lictype_Rec.Mailaddr2, c_Lictype_Rec.Mailcity, c_Lictype_Rec.Mailstate, c_Lictype_Rec.Mailzip);
    end if;

    sitespecific.pkg_Fees.GetPaymentTransactionsForJob(c_lictype_rec.Jobid, null, t_PTFeeObjectList);

        for i in 1..t_PTFeeObjectList.count loop
            insert into ABC.ABC261_RPT
            (Filenum, Licensee, Ltcode, Ltissdate, Amttype, Amtmi, Amtdup, Amtfeecode,
             Amttranscode, Amtearnedamt, Amtearneddate, Amtearnedtype, Testfield)
            -- PAYMENT TRANSACTIONS  -- C,R,V,I
            select c_Lictype_Rec.Filenum LicNum, c_Lictype_Rec.Licensee,
                   c_Lictype_Rec.Ltcode Ltcode, c_Lictype_Rec.Ltissdate,
                   --api.pkg_columnquery.VALUE (j.jobid,'PrimaryLicensee') Licensee,
                   SUBSTR(api.pkg_columnquery.VALUE(lfs.licensefeescheduleid,'LicenseTypeCode'),1,2),
                   lfs.ismaster MI, lfs.secondarycount Dup, FS.FeeCode,
                   FS.DESCRIPTION TransCode, ft.amount * -1 Amount,
                   to_date(to_char(QPT.Transactiondate,'mm/dd/yyyy'),'mm/dd/yyyy') TransDate,
                   CASE
                     WHEN (SELECT COUNT(*) FROM api.relationships r
                           WHERE  r.fromobjectid = x.objectid
                           AND    r.endpointid IN
                                    (api.pkg_configquery.endpointidforname('o_Payment','PaymentTransferAdjust'),
                                     api.pkg_configquery.endpointidforname('o_Payment','PaymentTransferTo')))>0
                     THEN 'C'
                     WHEN (SELECT COUNT(*) FROM api.relationships r
                           WHERE  r.fromobjectid = x.objectid
                           AND    r.endpointid = api.pkg_configquery.endpointidforname('o_Payment','RefundCheck'))>0
                     THEN 'R'
                     WHEN (SELECT COUNT(*) FROM api.relationships r
                           WHERE  r.fromobjectid = x.objectid
                           AND    r.endpointid = api.pkg_configquery.endpointidforname('o_Payment','VoidPayment'))>0
                     THEN 'V'
                     ELSE 'I'
                   END AmountType,
                   'Source=1, LTLicNum=' || api.pkg_columnquery.VALUE (j.jobid,'LicenseNumber')
                     || '-' || SUBSTR(api.pkg_columnquery.VALUE(lfs.licensefeescheduleid,'LicenseTypeCode'),1,2)
                     || ', Licensee=' || api.pkg_columnquery.VALUE (j.jobid,'PrimaryLicensee')
            FROM   QUERY.o_paymenttransactions qpt
            JOIN   api.paymenttransactions pt ON pt.transactionid = qpt.transactionid
            JOIN   api.payments p ON p.paymentid = pt.paymentid
            JOIN   api.feetransactions ft ON ft.transactionid = pt.transactionid
            JOIN   api.fees f ON f.feeid = ft.feeid
            JOIN   api.jobs j ON j.jobid = f.jobid
            JOIN   TABLE (CAST(api.pkg_simplesearch.castableobjectsbyindex('o_Payment','PaymentId',p.paymentid)
                           AS api.udt_objectlist)) x ON 1 = 1
            JOIN   TABLE (CAST(api.pkg_simplesearch.castableobjectsbyindex ('o_Fee','FeeId',f.feeid)
                           AS api.udt_objectlist)) z ON 1 = 1
            JOIN   QUERY.r_feelicensefeeschedule lfs ON lfs.feeobjectid = z.objectid
            join   QUERY.O_FEESCHEDULE fs on FS.OBJECTID = lfs.LICENSEFEESCHEDULEID
            WHERE  qpt.objectid = t_PTFeeObjectList(i).OBJECTID
            and    FS.LICENSETYPECODE in ('02','22')
            and    (FS.DESCRIPTION like 'ANN%' OR FS.DESCRIPTION like 'REN%')
            --and    FS.DESCRIPTION in ('ANN 4','REN 4')
            UNION
            -- PAYMENT TRANSACTIONS  -- G, A  (earned vs unearned)
            select c_Lictype_Rec.Filenum LicNum, c_Lictype_Rec.Licensee,
                   c_Lictype_Rec.Ltcode Ltcode, c_Lictype_Rec.Ltissdate,
                   --api.pkg_columnquery.VALUE (j.jobid,'PrimaryLicensee') Licensee,
                   SUBSTR(api.pkg_columnquery.VALUE(lfs.licensefeescheduleid,'LicenseTypeCode'),1,2),
                   --FS.LicenseTypeCode,
                   lfs.IsMaster MI, lfs.SecondaryCount Dup, FS.FeeCode, FS.Description TransCode,
                   CASE WHEN api.pkg_columnquery.VALUE (ps.objectid,'Status') = 'Earned'
                   THEN ft.amount* -1 --switch negative sign back if it does not work.
                   ELSE ft.amount * 1
                   END Amount,
                   to_date(to_char(QPT.Transactiondate,'mm/dd/yyyy'),'mm/dd/yyyy') TransDate,
                   CASE WHEN ps.systemgenerated = 'Y' THEN 'G' ELSE 'A'
                   END AmountType,
                   'Source=2, LTLicNum=' || api.pkg_columnquery.VALUE (j.jobid,'LicenseNumber')
                     || '-' || SUBSTR(api.pkg_columnquery.VALUE(lfs.licensefeescheduleid,'LicenseTypeCode'),1,2)
                     || ', Licensee=' || api.pkg_columnquery.VALUE (j.jobid,'PrimaryLicensee')
            FROM   QUERY.o_paymenttransactions qpt
            JOIN   api.paymenttransactions pt ON pt.transactionid = qpt.transactionid
            JOIN   api.payments p ON p.paymentid = pt.paymentid
            JOIN   QUERY.r_paymentstatuspaymenttrans pspt ON pspt.paymenttransactionobjectid = qpt.objectid
            JOIN   QUERY.o_paymentstatus ps ON ps.objectid = pspt.paymentstatusobjectid
            JOIN   api.feetransactions ft ON ft.transactionid = pt.transactionid
            JOIN   api.fees f ON f.feeid = ft.feeid
            JOIN   api.jobs j ON j.jobid = f.jobid
            JOIN   TABLE (CAST(api.pkg_simplesearch.castableobjectsbyindex
                               ('o_Payment','PaymentId',p.paymentid) AS api.udt_objectlist)) x ON 1 = 1
            JOIN   TABLE (CAST(api.pkg_simplesearch.castableobjectsbyindex
                               ('o_Fee','FeeId',f.feeid) AS api.udt_objectlist )) z ON 1 = 1
            JOIN   QUERY.r_feelicensefeeschedule lfs ON lfs.feeobjectid = z.objectid
            join   QUERY.O_FEESCHEDULE fs on FS.OBJECTID = lfs.LICENSEFEESCHEDULEID
            WHERE  qpt.objectid = t_PTFeeObjectList(i).OBJECTID
            AND    FS.LICENSETYPECODE in ('02','22')
            AND    (FS.DESCRIPTION like 'ANN%' OR FS.DESCRIPTION like 'REN%')
            --and    FS.DESCRIPTION in ('ANN 4','REN 4')
            order  by LicNum, LTcode;
        end loop;
  end loop;
  close c_lictype;

  commit;

END;
/


GRANT EXECUTE ON ABC.GEN_ABC261_RPT TO POSSEEXTENSIONS;
