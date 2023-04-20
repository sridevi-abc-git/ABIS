CREATE OR REPLACE PROCEDURE ABC.gen_active0222_no_AWF_rpt_2015 (a_maildate date default null,
                                                    a_duedate date default null,
                                                    a_firstnotice varchar2 default null)
as
-- **************************************************************************
-- File:        GEN_ACTIVE0222_NO_AWF_RPT_2015.PRC  
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

-- For Active 02/22 List Report, no parameter is needed.

t_ptfeeobjectlist   api.udt_objectlist;
t_count             pls_integer := 0;
t_yr                varchar2(2) := to_char(current_date,'YY');

-- Notice Report
t_maildate          date        := trunc(nvl(a_maildate,current_date));
t_duedate           date        := trunc(nvl(a_duedate,current_date));
t_firstnotice       varchar2(1) := nvl(upper(a_firstnotice),'Y');
t_issuedate         date        := to_date('05/31/'||t_yr,'mm/dd/yy');

t_startdate         date;
t_enddate           date;
t_transdatestart    date;
t_transdateend      date;


begin

  if t_issuedate > current_date then
    t_yr  := to_char(add_months(current_date,-12),'YY');
  end if;

  t_issuedate       := to_date('05/31/'||t_yr,'mm/dd/yy');
  t_startdate       := add_months(to_date('07/01/'||t_yr,'mm/dd/yy'),-12);
  t_enddate         := to_date('06/30/'||t_yr,'mm/dd/yy');
  t_transdatestart  := to_date('09/01/'||t_yr,'mm/dd/yy');
  t_transdateend    := add_months (to_date('01/07'||t_yr,'mm/dd/yy'),+12);


  delete from abc.ACTIVE0222_NO_AWF_RPT_2015;
  commit;

  --loop through all license types.
  for c_lictype in
    (select distinct l.jobid jobid, l.licensenumber filenum,
           upper(nvl(l.primarylicensee,l.primarydba)) licensee,
           l.statusname status, l.basefileofficecodecorral district,
           lt.licensetypecode ltcode, lt.statusname ltstatus,
           trunc(lt.expirationdate) ltexpdate,
           lt.gallonagerangefeecode ltfeecode,
           trunc(nvl(lt.issuedate,jsc.effectivestartdate)) ltissdate,
           upper(nvl(lt.licensemailingaddress2lines,lt.licensepremisesaddress2lines)) address
    from   query.j_license l
    join   query.r_licenselicensetype rlt on rlt.licensejobid = l.jobid
    join   query.j_licensetype lt on lt.jobid = rlt.licensetypejobid
    join   api.jobstatuses js1 on js1.jobtypeid = l.jobtypeid and js1.statusid = l.statusid and js1.statustype in ('O','I')
    join   api.jobstatuses js2 on js2.jobtypeid = lt.jobtypeid and js2.statusid = lt.statusid and js2.statustype in ('O','I')
    left   outer join extension.jobstatuschange_t jsc on jsc.jobid = lt.jobid and jsc.mostrecent = 'Y'
    where  l.licensenumber is not null
    and    nvl(l.primarylicensee,l.primarydba) is not null
    and    lt.licensetypecode is not null
    and    lt.gallonagerangefeecode is not null
    and    lt.licensetypecode in ('02','22')
    and    trunc(nvl(lt.issuedate,jsc.effectivestartdate)) <= t_issuedate
    union
    select distinct l.jobid jobid, l.licensenumber filenum,
           upper(nvl(l.primarylicensee,l.primarydba)) licensee,
           l.statusname status, l.basefileofficecodecorral district,
           oltc.licensetypecode ltcode, lt.statusname ltstatus,
           trunc(lt.expirationdate) ltexpdate,
           lt.gallonagerangefeecode ltfeecode,
           trunc(nvl(lt.issuedate,jsc.effectivestartdate)) ltissdate,
           upper(nvl(lt.licensemailingaddress2lines,lt.licensepremisesaddress2lines)) address
    from   query.j_license l
    join   query.r_licenselicensetype rlt on rlt.licensejobid = l.jobid
    join   query.j_licensetype lt on lt.jobid = rlt.licensetypejobid
    join   query.r_licensetypeltcatsecondary slt on slt.licensetypejobid = lt.jobid
    join   query.o_licensetypecategory oltc on oltc.objectid = slt.licensetypecategoryobjectid
    join   api.jobstatuses js1 on js1.jobtypeid = l.jobtypeid and js1.statusid = l.statusid and js1.statustype in ('O','I')
    join   api.jobstatuses js2 on js2.jobtypeid = lt.jobtypeid and js2.statusid = lt.statusid and js2.statustype in ('O','I')
    left   outer join extension.jobstatuschange_t jsc on jsc.jobid = lt.jobid and jsc.mostrecent = 'Y'
    where  l.licensenumber is not null
    and    nvl(l.primarylicensee,l.primarydba) is not null
    and    lt.licensetypecode is not null
    and    lt.gallonagerangefeecode is not null
    and    oltc.licensetypecode in ('02','22')
    and    trunc(nvl(lt.issuedate,jsc.effectivestartdate)) <= t_issuedate
    )

  loop

    select count(*) into t_count
    from   abc.ACTIVE0222_NO_AWF_RPT_2015
    where  filenum = c_lictype.filenum
    and    ltcode = c_lictype.ltcode
    and    rownum = 1;

    if t_count = 0 then
      insert into abc.ACTIVE0222_NO_AWF_RPT_2015
      (filenum, licensee, status, district, ltcode, ltstatus, ltexpdate,
       ltfeecode, ltissdate, address, maildate, duedate, firstnotice,
       startdate, enddate, issuedate, transdatestart, transdateend )
      values
      (c_lictype.filenum, c_lictype.licensee, c_lictype.status, c_lictype.district,
       c_lictype.ltcode, c_lictype.ltstatus, c_lictype.ltexpdate, c_lictype.ltfeecode,
       c_lictype.ltissdate, c_lictype.address, t_maildate, t_duedate, t_firstnotice,
       t_startdate, t_enddate, t_issuedate, t_transdatestart, t_transdateend);
    end if;

    if a_maildate is null and a_duedate is null and a_firstnotice is null then

      sitespecific.pkg_fees.getpaymenttransactionsforjob(c_lictype.jobid,null,t_ptfeeobjectlist);

      for i in 1..t_ptfeeobjectlist.count loop

        insert into abc.ACTIVE0222_NO_AWF_RPT_2015
        (filenum, licensee, ltcode, ltissdate, amttype, amtmi, amtdup,
         amtfeecode, amttranscode, amtearnedamt, amtearneddate, amtearnedtype,
         --testfield,
         issuedate, transdatestart, transdateend  )
        -- Payment Transactions  -- C,R,V,I
        select c_lictype.filenum licnum, c_lictype.licensee,
               c_lictype.ltcode ltcode, c_lictype.ltissdate,
               qpt.licensetypecode licensetypecode, qpt.IsMaster mi,
               qpt.SecondaryCount dup, qpt.feecode feecode,
               Case when qpt.IsServiceCharge = 'Y' then 'SRV' 
                    when qpt.IsOverpayment = 'Y' then 'OVR' else qpt.feescheduletransactioncode
               end transcode,
               ft.amount*-1 amount, trunc(qpt.transactiondate) transdate,
               case when (select 'x' from api.relationships r where  r.fromobjectid = x.objectid
                          and    r.endpointid in
                                (api.pkg_configquery.endpointidforname('o_Payment','PaymentTransferAdjust'),
                                 api.pkg_configquery.endpointidforname('o_Payment','PaymentTransferTo'))
                          and rownum = 1 ) = 'x'
                    then 'C'
                    when (select 'x' from api.relationships r where  r.fromobjectid = x.objectid
                          and    r.endpointid = api.pkg_configquery.endpointidforname('o_Payment','RefundCheck')
                          and rownum = 1 ) = 'x'
                    then 'R'
                    when (select 'x' from api.relationships r where  r.fromobjectid = x.objectid
                          and    r.endpointid = api.pkg_configquery.endpointidforname('o_Payment','VoidPayment')
                          and rownum = 1 ) = 'x'
                    then 'V'
                    else 'I'
               end amounttype,
               --'Source=1, LTLicNum=' || api.pkg_columnquery.value (c_lictype.jobid,'LicenseNumber') testfield,
               t_issuedate, t_transdatestart, t_transdateend
        from   query.o_paymenttransactions qpt
        join   api.paymenttransactions pt on pt.transactionid = qpt.transactionid
        join   api.feetransactions ft on ft.transactionid = pt.transactionid
        join   table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Payment', 'PaymentId', pt.PaymentId) as api.udt_objectlist)) x on 1 = 1
        where  qpt.objectid = t_ptfeeobjectlist(i).objectid
        and    qpt.licensetypecode = c_lictype.ltcode
        --and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN')
         and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN', 'REN50','REN100')
        --and    qpt.feescheduletransactionfeeactiv not in ('AWF')
        and    qpt.feecode is not null
        and    trunc(qpt.transactiondate) between t_transdatestart and t_transdateend
        ;

        insert into abc.ACTIVE0222_NO_AWF_RPT_2015
        (filenum, licensee, ltcode, ltissdate, amttype, amtmi, amtdup,
         amtfeecode, amttranscode, amtearnedamt, amtearneddate, amtearnedtype,
         --testfield,
         issuedate, transdatestart, transdateend  )
        -- Payment Transactions  -- G, A  (earned vs unearned)
        select c_lictype.filenum licnum, c_lictype.licensee,
               c_lictype.ltcode ltcode, c_lictype.ltissdate,
               qpt.licensetypecode licensetypecode, qpt.IsMaster mi,
               qpt.SecondaryCount dup, qpt.feecode feecode,
               Case when qpt.IsServiceCharge = 'Y' then 'SRV' 
                    when qpt.IsOverpayment = 'Y' then 'OVR' else qpt.feescheduletransactioncode
               end transcode,
               case when upper(api.pkg_columnquery.Value(pspt.paymentStatusObjectid, 'Status')) = 'EARNED'
                    then ft.Amount else ft.Amount*-1 --switch negative sign back if it does not work.
               end  amount,
               trunc(qpt.transactiondate) transdate,
               case
                 when api.pkg_columnquery.Value(pspt.PaymentStatusObjectId, 'SystemGenerated') = 'Y'
                 then 'G' else 'A'
               end amounttype,
               --'Source=2, LTLicNum=' || api.pkg_columnquery.value (c_lictype.jobid,'LicenseNumber') testfield,
               t_issuedate, t_transdatestart, t_transdateend
        from   query.o_paymenttransactions qpt
        join   api.paymenttransactions pt on pt.transactionid = qpt.transactionid
        join   table(cast(api.pkg_simplesearch.CastableObjectsByIndex('o_Payment', 'PaymentId', pt.PaymentId) as api.udt_objectlist)) x on 1 = 1
        join   api.feetransactions ft on ft.transactionid = pt.transactionid
        join   query.r_paymentstatuspaymenttrans pspt on pspt.paymenttransactionobjectid = qpt.objectid
        where  qpt.objectid = t_ptfeeobjectlist(i).objectid
        and    qpt.licensetypecode = c_lictype.ltcode
        --and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN')
         and    qpt.feescheduletransactionfeeactiv in ('ANN', 'REN', 'REN50','REN100')
        --and    qpt.feescheduletransactionfeeactiv not in ('AWF')
        and    qpt.feecode is not null
        and    trunc(qpt.transactiondate) between t_transdatestart and t_transdateend
        ;

      end loop;

    end if;

  end loop;

  commit;

end gen_active0222_no_AWF_rpt_2015;
/
