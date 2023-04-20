CREATE OR REPLACE PROCEDURE ABC.GetPurgeList(a_StartDate date default trunc(sysdate-360),
                                             a_EndDate date default trunc(sysdate))
as

-- For Purge list report
begin

  delete from abc.purge_list;
  --commit;  --comment it out for production

  --loop through all license types.
  for c_lictype in (Select
                        JL.JOBID,
                        JL.LICENSENUMBER
                    From QUERY.J_LICENSE JL
                    Join QUERY.R_LICENSELICENSETYPE RLT on JL.JOBID = RLT.LICENSEJOBID
                    Join QUERY.J_LICENSETYPE JLT on RLT.LICENSETYPEJOBID = JLT.JOBID
                    --Join EXTENSION.JOBSTATUSCHANGE ST on JLT.JOBID = ST.JOBID
                    where NVL(JL.STATUSDATE,JLT.STATUSDATE) BETWEEN a_StartDate and a_EndDate
                    and JLT.LICENSETYPECODE not between '30' and '39'
                    and JLT.LICENSETYPECODE not in ('09','11','12','58','66','68','77','79','81')
                    and UPPER (JLT.STATUSNAME) in ('AUTREV', 'CANCEL', 'DENIED', 'NREN', 'REVPEN', 'VOIDED', 'WTHDRN','SLMSRV')
                    --and JL.OBJECTID in (19186165,19310005,19401299)
                    UNION
                    Select
                        JL.JOBID,
                        JL.LICENSENUMBER licenseno
                    From QUERY.J_LICENSE JL
                    Join QUERY.R_LICENSELICENSETYPE RLT on JL.JOBID = RLT.LICENSEJOBID
                    Join QUERY.J_LICENSETYPE JLT on RLT.LICENSETYPEJOBID = JLT.JOBID
                    JOIN query.r_LicenseTypeLTCatSecondary slt ON slt.LicenseTypeJobId = JLT.JobId
                    JOIN query.o_Licensetypecategory oltc on oltc.ObjectId = slt.LicenseTypeCategoryObjectId
                    where NVL(JL.STATUSDATE,SLT.STATUSDATE) BETWEEN a_StartDate and a_EndDate
                    and OLTC.LICENSETYPECODE not between '30' and '39'
                    and OLTC.LICENSETYPECODE not in ('09','11','12','58','66','68','77','79','81')
                    and UPPER (SLT.STATUS) in ('AUTREV', 'CANCEL', 'DENIED', 'NREN', 'REVPEN', 'VOIDED', 'WTHDRN','SLMSRV')
                    --and JL.OBJECTID in (19186165,19310005,19401299)
                    )

  loop

    INSERT INTO abc.purge_list
    Select
        JL.JOBID,
        JL.LICENSENUMBER licenseno,
        JL.STATUSNAME lic_status,
        JL.STATUSDATE lic_statusdate,
        JLT.LICENSETYPECODE LICENSETYPECODE,
        JLT.STATUSNAME TYPE_STATUS_CODE,
        JLT.STATUSDATE TYPE_STATUS_DATE,
        JLT.ISSUEDATE TYPE_ORIGINAL_ISSUE_DATE,
        JL.PRIMARYLICENSEE name
    From QUERY.J_LICENSE JL
    Join QUERY.R_LICENSELICENSETYPE RLT on JL.JOBID = RLT.LICENSEJOBID
    Join QUERY.J_LICENSETYPE JLT on RLT.LICENSETYPEJOBID = JLT.JOBID
    where JLT.LICENSETYPECODE not between '30' and '39'
    and JLT.LICENSETYPECODE not in ('09','11','12','58','66','68','77','79','81')
    and JL.OBJECTID = c_lictype.jobid
    UNION
    Select
        JL.JOBID,
        JL.LICENSENUMBER licenseno,
        JL.STATUSNAME lic_status,
        JL.STATUSDATE lic_statusdate,
        OLTC.licensetypecode LicType,
        SLT.STATUS TYPE_STATUS_CODE,
        SLT.STATUSDATE TYPE_STATUS_DATE,
        SLT.ISSUEDATE TYPE_ORIGINAL_ISSUE_DATE,
        JL.PRIMARYLICENSEE name
    From QUERY.J_LICENSE JL
    Join QUERY.R_LICENSELICENSETYPE RLT on JL.JOBID = RLT.LICENSEJOBID
    Join QUERY.J_LICENSETYPE JLT on RLT.LICENSETYPEJOBID = JLT.JOBID
    JOIN query.r_LicenseTypeLTCatSecondary slt ON slt.LicenseTypeJobId = JLT.JobId
    JOIN query.o_Licensetypecategory oltc on oltc.ObjectId = slt.LicenseTypeCategoryObjectId
    where OLTC.LICENSETYPECODE not between '30' and '39'
    and OLTC.LICENSETYPECODE not in ('09','11','12','58','66','68','77','79','81')
    and JL.OBJECTID = c_lictype.jobid;

  end loop;

  --commit; --COMMIT OUT IN PRODUCTION

end GetPurgeList;
/


GRANT EXECUTE ON ABC.GETPURGELIST TO POSSEEXTENSIONS;
