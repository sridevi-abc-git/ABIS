CREATE OR REPLACE PROCEDURE ABC.gen_late_penalties 
( a_StartDate date,
  a_EndDate date
)
as  
-- **************************************************************************
-- File:        GEN_LATE_PENALTIES.PRC  
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
  t_Amount                number := 0;
  t_RENAmount             number := 0;
  t_PENAmount             number := 0;
  t_BKR                   number := 0;
  t_BKT                   number := 0;
  t_CaterersClubs         number := 0;
  t_CatEventAuth          number := 0;
  t_CatEventPermit        number := 0;
  t_DishonoredChecks      number := 0;
  t_ExpirationDate        date;
  t_FeeActivity           varchar2(10);
  t_FeeAmount             number := 0;
  t_FingerprintFees       number := 0;
  t_IncreaseFees          number := 0;
  t_LicenseFees           number := 0;
  t_MGR                   number := 0;
  t_MiscOvrpm             number := 0;
  t_MOD                   number := 0;
  t_Other                 number := 0;
  t_PaidAmount            number := 0;
  t_UnPaidREN             number := 0;
  t_Penalties             number := 0;
  t_POIC                  number := 0;
  t_PrevPaid              number := 0;
  t_PRW                   number := 0;
  t_Replacements          number := 0;
  t_RevenueCode           varchar2(20);
  t_s70                   number := 0;
  t_ScheduleId            api.pkg_Definition.udt_Id;
  t_ServiceChrg           number := 0;
  t_Transfers             number := 0;
  t_WineSafety            number := 0;

  begin

  delete LATE_PENALTIES;

    for c in (select api.pkg_ColumnQuery.NumericValue(ps.ObjectId, 'EarnedAmount') Amount,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'Converted') Converted,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'TransactionCode') Description,
                     api.pkg_ColumnQuery.DateValue(f.ObjectId, 'RENExpirationDate') ExpirationDate,
                     nvl(api.pkg_ColumnQuery.Value(ps.ObjectId, 'FeeActivity'), mfs.Code) FeeActivity,
                     ft.FeeId,
                     api.pkg_ColumnQuery.NumericValue(f.ObjectId, 'Amount') FeeAmount,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'GallonageRangeFeeCode') GallonageRange,
                     api.pkg_ColumnQuery.NumericValue(f.ObjectId, 'JobId') JobId,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'LicenseTypeCode') LicenseTypeCode,
                     api.pkg_columnquery.value(ps.ObjectId, 'SecondaryCount') SecondaryCount,
                     api.pkg_columnquery.value(ps.ObjectId, 'MasterLT') MasterLT,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'NumberOfMonthsLicensedFeeCode') NumberOfMonthsLicensed,
                     api.pkg_ColumnQuery.NumericValue(f.ObjectId, 'PaidAmount') PaidAmount,
                     api.pkg_ColumnQuery.Value(ps.ObjectId, 'PopulationRangeFeeCode') PopulationRange,
                     api.pkg_ColumnQuery.Value(pt.ObjectId, 'FeeScheduleDescriptionForGrid') PTDescription,
                     ft.TransactionId,
                     api.pkg_columnquery.Value(ps.ObjectId, 'Status') PaymentStatus
                from table(cast(api.pkg_SimpleSearch.CastableObjectsByIndexRange('o_PaymentStatus',
                                                                                 'dup_CreatedDate',
                                                                                 to_char(a_StartDate, 'YYYY-MM-DD'),
                                                                                 to_char(a_EndDate, 'YYYY-MM-DD')) as api.udt_ObjectList)) ps
                join api.Objects o on o.ObjectId = ps.ObjectId
                join query.r_PaymentStatusPaymentTrans pspt on pspt.PaymentStatusObjectId = ps.ObjectId
                join query.o_PaymentTransactions pt on pt.ObjectId = pspt.PaymentTransactionObjectId
                join api.FeeTransactions ft on ft.TransactionId = pt.TransactionId
                join api.fees af on af.FeeId = ft.feeid
                join query.o_fee f on f.ObjectId = api.pkg_simplesearch.ObjectByIndex('o_fee', 'FeeId', af.Feeid)
                join api.relationships r on r.FromObjectId = f.ObjectId
                     and r.EndpointId in (api.pkg_ConfigQuery.EndPointIdForName('o_Fee','LicenseFeeSchedule'),
                                          api.pkg_ConfigQuery.EndPointIdForName('o_Fee','MiscFeeSchedule'))
                left outer join query.o_MiscFeeSchedule mfs on mfs.ObjectId = r.ToObjectId
               where /*api.pkg_columnquery.value(ps.objectid, 'FeeActivity') in ('PEN','REN50','REN100') 
                 and*/ (api.pkg_columnquery.value(ps.objectid, 'Converted') = 'N' -- not converted
                 and (mfs.Code is null
                  or mfs.Code = 'UTR'))
                  or (api.pkg_columnquery.value(ps.objectid, 'Converted') = 'Y' --when it is converted
                 and api.pkg_columnquery.value(ps.objectid, 'FeeActivity') not in (select m.Code
                                                                                     from query.o_miscfeeschedule m
                                                                                    where m.code <> 'UTR'))) loop

      If c.FeeActivity not like 'REN%' or c.Converted = 'Y' then
        If c.PTDescription = 'OVR' then
          t_Other := t_Other + c.Amount;
          t_RevenueCode := 'OTHER';
        Elsif c.PTDescription like '%SRV' then
          t_ServiceChrg := t_ServiceChrg + c.Amount;
          t_RevenueCode := 'SRVCHG';
       /* Elsif c.FeeActivity = '70S' then
          t_s70 := t_s70 + c.Amount;
          t_RevenueCode := '70S';*/
        Elsif c.FeeActivity in ('REN', 'ORI', 'ANN','ICF', 'DOR', 'ODL', 'SPD', 'TPT',
                                'IPT', 'AWF', 'TST', 'SDV') and (c.LicenseTypeCode not in ('58','77') or c.LicenseTypeCode is null) then
          t_LicenseFees := t_LicenseFees + c.Amount;
          t_RevenueCode := 'LICFEE';
        Elsif c.FeeActivity in ('CATA','EPA') then
          t_CatEventAuth := t_CatEventAuth + c.Amount;
          t_RevenueCode := 'CAUTH583';
        Elsif c.FeeActivity in ('REN', 'ORI', 'ANN', 'ICF', 'DOR', 'ODL', 'TPT')
             and c.LicenseTypeCode in ('58','77') then
          If c.MasterLT in ('50', '51', '52') and c.LicenseTypeCode = '58' then
            t_CaterersClubs := t_CaterersClubs + c.Amount;
            t_RevenueCode := 'CLUBCAT';
          Elsif (c.MasterLT not in ('50', '51', '52') or c.MasterLT is null) and c.LicenseTypeCode = '58' then
            t_CatEventPermit := t_CatEventPermit + c.Amount;
            t_RevenueCode := 'CATPERM';
          Elsif c.LicenseTypeCode = '77' then
            t_CatEventPermit := t_CatEventPermit + c.Amount;
            t_RevenueCode := 'CATPERM';
          End If;
        Elsif c.FeeActivity = 'MGR' then
          t_MGR := t_MGR + c.Amount;
          t_RevenueCode := 'MANQ321';
        Elsif c.FeeActivity = 'PEN' then
          t_Penalties := t_Penalties + c.Amount;
          t_RevenueCode := 'PENALTY';
        Elsif c.FeeActivity = 'PRW' then
          t_PRW := t_PRW + c.Amount;
          t_RevenueCode := 'PRIVWARE';
        Elsif c.FeeActivity = 'UTR' then
          t_MiscOvrpm := t_MiscOvrpm + c.Amount;
          t_RevenueCode := 'UNCLAIM';
        Elsif c.FeeActivity = 'POIC' then
          t_POIC := t_POIC + c.Amount;
          t_RevenueCode := 'POIC';
        Elsif c.FeeActivity = 'MOD' then
          t_MOD := t_MOD + c.Amount;
          t_RevenueCode := 'COND803';
        Elsif c.FeeActivity = 'RPL' then
          t_Replacements := t_Replacements + c.Amount;
          t_RevenueCode := 'REPLACE';
        Elsif c.FeeActivity = 'CD8' then
          t_IncreaseFees := t_IncreaseFees + c.Amount;
          t_RevenueCode := 'FEEINC';
        Elsif c.FeeActivity in ('EXC', 'PER', 'ICO', 'FID', 'STK', 'STM', 'PRM', 'MBR', 'DPR', 'MBM') then
          t_Transfers := t_Transfers + c.Amount;
          t_RevenueCode := 'XFER';
        Elsif c.FeeActivity = 'BKT' then
          t_BKT := t_BKT + c.Amount;
          t_RevenueCode := 'BKT';
        Elsif c.FeeActivity = 'BKR' then
          t_BKR := t_BKR + c.Amount;
          t_RevenueCode := 'BKR';
        Elsif c.FeeActivity = 'CHK' then -- TODO: Dishonored Checks
          t_DishonoredChecks := t_DishonoredChecks + c.Amount;
          t_RevenueCode := 'BADCHK';
        Elsif c.FeeActivity in ('FFP','SFP') then
          t_FingerprintFees := t_FingerprintFees + c.Amount;
          t_RevenueCode := 'FNGRPRNT';
        Else
          t_Other := t_Other + c.Amount;
          t_RevenueCode := 'OTHER';
        End If;

        insert into LATE_PENALTIES(PayStatus,
                                           TransCode,
                                           LTCode,
                                           Master_Ind,
                                           Amount)
                                    values(c.PaymentStatus ,
                                           case
                                           when c.PTDescription like '%SRV' or c.PTDescription = 'OVR' then
                                             c.PTDescription
                                           when c.feeactivity = 'ODL' then
                                             substr(c.description, 1, 3)
                                           else
                                             nvl(c.Description, 'NA')
                                           end,
                                           case when c.FeeActivity in ('FFP','SFP') then
                                             'NA'
                                           else
                                             nvl(c.LicenseTypeCode,
                                                 nvl(api.pkg_ColumnQuery.Value(c.JobId,
                                                                               'ApplicableLicenseType'),
                                                 'NA'))
                                           end,
                                           decode(c.MasterLT,NULL,'Y',NULL),
                                           c.Amount);

    ElsIf c.FeeActivity like 'REN%'  and c.Converted = 'N' then

        t_FeeActivity := c.FeeActivity;
        t_FeeAmount := 0;
        t_PrevPaid := 0;
        t_UnPaidREN := 0;
        t_RENAmount := 0;
        t_PENAmount := 0;

        If c.PTDescription = 'OVR' then
          t_Other := t_Other + c.Amount;
          t_RevenueCode := 'OTHER';

          insert into LATE_PENALTIES(PayStatus,
                                             TransCode,
                                             LTCode,
                                             Master_Ind,
                                             Amount)
                                      values(c.PaymentStatus,
                                             c.PTDescription,
                                             case when c.FeeActivity in ('FFP','SFP') then
                                               'NA'
                                             else
                                               nvl(c.LicenseTypeCode,
                                                   nvl(api.pkg_ColumnQuery.Value(c.JobId,
                                                                                 'ApplicableLicenseType'),
                                                   'NA'))
                                             end,
                                             decode(c.MasterLT,NULL,'Y',NULL),
                                             c.Amount);

        Else

          t_ExpirationDate := c.ExpirationDate;

          -- if the Expiration Date from the Fee (RENExpirationDate) is null
          if t_ExpirationDate is null then
            -- if the fee is on a License Type Job, get the expirationdate from the job
            if api.pkg_ColumnQuery.Value(c.JobId, 'ObjectDefName') = 'j_LicenseType' then
              begin
                select decode(substr(c.Description,-1),
                              '9',
                              to_date( -- Final Date
                                to_char( -- Day of month
                                  last_day(
                                    '01-'||to_char(last_day(api.pkg_ColumnQuery.DateValue(c.JobId, 'ExpirationDate')),'MON')
                                    ||'-2009'
                                  ),'DD'
                                ) -- End Day of month
                                ||'-'||to_char(api.pkg_ColumnQuery.DateValue(c.JobId, 'ExpirationDate'),'MON') -- Month
                                ||'-2009' -- Year
                              ), -- End Final Date
                              'A',
                              to_date( -- Final Date
                                to_char( -- Day of month
                                  last_day(
                                    '01-'||to_char(last_day(api.pkg_ColumnQuery.DateValue(c.JobId, 'ExpirationDate')),'MON')
                                    ||'-2010'
                                  ),'DD'
                                ) -- End Day of month
                                ||'-'||to_char(api.pkg_ColumnQuery.DateValue(c.JobId, 'ExpirationDate'),'MON') -- Month
                                ||'-2010' -- Year
                              ), -- End Final Date
                              last_day(sysdate))
                 into t_ExpirationDate
                 from dual;
              exception
              when others then
                t_ExpirationDate := last_day(sysdate);
              end;
            -- if the fee is on a License, get the ExpirationDate from the related LT where the LTCode = the Fee LT Code
            elsif api.pkg_ColumnQuery.Value(c.JobId, 'ObjectDefName') = 'j_License' then
              begin
                select nvl(max(decode(substr(c.Description,-1),
                              '9',
                              to_date( -- Final Date
                                to_char( -- Day of month
                                  last_day(
                                    '01-'||to_char(last_day(api.pkg_ColumnQuery.DateValue(llt.LicenseTypeJobId, 'ExpirationDate')),'MON')
                                    ||'-2009'
                                  ),'DD'
                                ) -- End Day of month
                                ||'-'||to_char(api.pkg_ColumnQuery.DateValue(llt.LicenseTypeJobId, 'ExpirationDate'),'MON') -- Month
                                ||'-2009' -- Year
                              ), -- End Final Date
                              'A',
                              to_date( -- Final Date
                                to_char( -- Day of month
                                  last_day(
                                    '01-'||to_char(last_day(api.pkg_ColumnQuery.DateValue(llt.LicenseTypeJobId, 'ExpirationDate')),'MON')
                                    ||'-2010'
                                  ),'DD'
                                ) -- End Day of month
                                ||'-'||to_char(api.pkg_ColumnQuery.DateValue(llt.LicenseTypeJobId, 'ExpirationDate'),'MON') -- Month
                                ||'-2010' -- Year
                              ))),  -- End Final Date
                              last_day(sysdate))
                  into t_ExpirationDate
                  from query.j_License l
                  join query.r_LicenseLicenseType llt on llt.LicenseJobId = l.JobId
                  join api.JobStatuses js on js.JobTypeId = l.JobTypeId
                 where api.pkg_ColumnQuery.Value(llt.LicenseTypeJobId,'LicenseTypeCode') = c.LicenseTypeCode
                   and js.StatusType not in ('C','X');
              exception
              when others then
                t_ExpirationDate := last_day(sysdate);
              end;

            else
              t_ExpirationDate := last_day(sysdate);
            end if;
          end if;

          sitespecific.pkg_Fees.GetLTFeeAmount(null,
                                               t_ExpirationDate,
                                               'REN',
                                               null,
                                               c.LicenseTypeCode,
                                               c.GallonageRange,
                                               null,
                                               c.NumberOfMonthsLicensed,
                                               c.PopulationRange,
                                               case
                                               when c.MasterLT is not null then
                                                 'S'
                                               else
                                                 'P'
                                               end,
                                               c.SecondaryCount,
                                               null,
                                               t_FeeAmount,
                                               t_ScheduleId);

          -- Round Fee Amount
          t_FeeAmount := round(t_FeeAmount);

          t_ExpirationDate := null;

          begin
            select sum(ft.Amount)
              into t_PaidAmount
              from api.FeeTransactions ft
             where ft.FeeId = c.FeeId
               and ft.TransactionType = 'Pay'
               and ft.TransactionId <= c.TransactionId;
          exception
          when OTHERS then
            t_PaidAmount := 0;
          end;

          If t_FeeActivity = 'REN' then
            t_RENAmount := c.Amount;
          Elsif t_FeeActivity in ('REN50','REN100') then

            t_PrevPaid := t_PaidAmount + abs(c.Amount);
            t_UnPaidREN := t_FeeAmount + t_PrevPaid;

            -- Set the case for t_UnPaidREN
            if c.Amount > 0 then
              t_UnPaidREN := -t_UnPaidREN;
            end if;

            -- If the previous payments did not cover the whole original REN Fee
            If (t_UnPaidREN > 0 and c.Amount < 0) or (t_UnPaidREN < 0 and c.Amount > 0) then
              if abs(c.Amount) < abs(t_UnPaidREN) then
                t_RENAmount := c.Amount;
              else
                t_RENAmount := -t_UnPaidREN;
                t_PENAmount := t_UnPaidREN + c.Amount;
              end if;
            Else
              t_PENAmount := c.Amount;
            End If;

          End If;

          If t_RENAmount <> 0 then
            If (c.LicenseTypeCode not in ('58','77') or c.LicenseTypeCode is null) then
              t_LicenseFees := t_LicenseFees + t_RENAmount;
              t_RevenueCode := 'LICFEE';
            Elsif c.LicenseTypeCode in ('58','77') then
              If c.MasterLT in ('50', '51', '52') and c.LicenseTypeCode = '58' then
                t_CaterersClubs := t_CaterersClubs + t_RENAmount;
                t_RevenueCode := 'CLUBCAT';
              Elsif (c.MasterLT not in ('50', '51', '52') or c.MasterLT is null) and c.LicenseTypeCode = '58' then
                t_CatEventPermit := t_CatEventPermit + t_RENAmount;
                t_RevenueCode := 'CATPERM';
              Elsif c.LicenseTypeCode = '77' then
                t_CatEventPermit := t_CatEventPermit + t_RENAmount;
                t_RevenueCode := 'CATPERM';
              End If;
            End If;

            insert into LATE_PENALTIES(PayStatus,
                                               TransCode,
                                               LTCode,
                                               Master_Ind,
                                               Amount)
                                        values(c.PaymentStatus,
                                               nvl(replace(c.Description, substr(c.Description,1,instr(c.Description,' ')),'REN '), 'NA'),
                                               case when c.FeeActivity in ('FFP','SFP') then
                                                 'NA'
                                               else
                                                 nvl(c.LicenseTypeCode,
                                                     nvl(api.pkg_ColumnQuery.Value(c.JobId,
                                                                                   'ApplicableLicenseType'),
                                                     'NA'))
                                               end,
                                               decode(c.MasterLT,NULL,'Y',NULL),
                                               t_RENAmount);

          End If;

          If t_PENAmount <> 0 then
            t_Penalties := t_Penalties + t_PENAmount;
            t_RevenueCode := 'PENALTY';

            insert into LATE_PENALTIES(PayStatus,
                                               TransCode,
                                               LTCode,
                                               Master_Ind,
                                               Amount)
                                        values(c.PaymentStatus,
                                               nvl(replace(c.Description, substr(c.Description,1,instr(c.Description,' ')),'PEN '), 'NA'),
                                               case when c.FeeActivity in ('FFP','SFP') then
                                                 'NA'
                                               else
                                                 nvl(c.LicenseTypeCode,
                                                     nvl(api.pkg_ColumnQuery.Value(c.JobId,
                                                                                   'ApplicableLicenseType'),
                                                     'NA'))
                                               end,
                                               decode(c.MasterLT,NULL,'Y',NULL),
                                               t_PENAmount);

          End If;
        End If;
      End If;
    end loop;

  end;
/
