CREATE OR REPLACE PROCEDURE ABC.PRO_CENSUS_TRACT_COUNTY(a_county_code varchar2) AS
    -- **************************************************************************
    -- File:        PRO_CENSUS_TRACT_COUNTY.PRC  
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
    -- 08/21/2018 TJL         Initial Check-in   
    -- **************************************************************************

CURSOR c_license_ct IS
    SELECT DISTINCT addr.countycode countycode, addr.countyname countyname,
                       ap.premcensustract premcensustract,
                       ap.basefileofficecodecorral district,
                       ap.basefileofficename, ap.licensenumber licensenumber,
                       lt.licensetypecode licensetypecode,
                       lt.licensetypename licensetypename,
                       lt.applicationstatus status,
                       DECODE (   DECODE (OLT.RETAILTYPE,
                                              'On-Sale', 'Y',
                                              'N'
                                         )
                               || DECODE (lt.applicationstatus,
                                          'PEND', 'N',
                                          'ISUSSED', 'N',
                                          'NEW', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) on_act_ind,
                       DECODE
                          (DECODE (   DECODE (OLT.RETAILTYPE,
                                              'On-Sale', 'Y',
                                              'N'
                                             )
                                   || DECODE (lt.applicationstatus,
                                              'PEND', 'N',
                                              'ISUSSED', 'N',
                                              'NEW', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) on_act_ind_num,
                       DECODE (   DECODE (OLT.RETAILTYPE,
                                              'Off-Sale', 'Y',
                                              'N'
                                         )
                               || DECODE (lt.applicationstatus,
                                          'PEND', 'N',
                                          'ISUSSED', 'N',
                                          'NEW', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) off_act_ind,
                       DECODE
                          (DECODE (   DECODE (OLT.RETAILTYPE,
                                              'Off-Sale', 'Y',
                                              'N'
                                             )
                                   || DECODE (lt.applicationstatus,
                                              'PEND', 'N',
                                              'ISUSSED', 'N',
                                              'NEW', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) off_act_ind_num,
                       CASE
                          WHEN OLT.RETAILTYPE = 'Off-Sale'
                             THEN 'Y'
                          ELSE 'N'
                       END off_pend_ind,
                       CASE
                          WHEN OLT.RETAILTYPE = 'On-Sale'
                             THEN 'Y'
                          ELSE 'N'
                       END on_pend_ind,

    --
                       DECODE
                          ((CASE
                               WHEN OLT.RETAILTYPE = 'Off-Sale'
                                  THEN 'Y'
                               ELSE 'N'
                            END
                           ),
                           'Y', 1,
                           0
                          ) off_pend_ind_num,
                       DECODE
                          ((CASE
                               WHEN OLT.RETAILTYPE = 'On-Sale'
                                  THEN 'Y'
                               ELSE 'N'
                            END
                           ),
                           'Y', 1,
                           0
                          ) on_pend_ind_num
    From QUERY.J_APPLICATION AP
    Join QUERY.R_APPPRIMARYLICENSETYPE RAL on RAL.APPLICATIONOBJECTID = AP.OBJECTID
    Join QUERY.O_PRIMARYLICENSETYPE LT on LT.OBJECTID = RAL.LICENSETYPEOBJECTID
    Join Query.r_PriLTLTCatPrimary RPS on RPS.PRIMARYLICENSETYPEOBJECTID = LT.OBJECTID
    Join QUERY.O_LICENSETYPECATEGORY OLT on OLT.OBJECTID = RPS.LICENSETYPECATEGORYOBJECTID
    join QUERY.R_APPLICATIONPREMADDR APA ON APA.APPLICATIONJOBID = AP.OBJECTID
    join QUERY.O_ADDRESS ADDR ON ADDR.OBJECTID = APA.ADDRESSOBJECTID
    where ( OLT.RETAILTYPE in ('On-Sale','Off-Sale' )
           or (OLT.LICENSETYPECODE in ('47','48','49') and LT.HASSECONDARY='Y')
           and AP.STATUSNAME in ('PEND','ISUSSED','NEW')
          )
    and ADDR.COUNTYCODE = a_county_code
    --and AP.LICENSENUMBER in (754220,753294,753857)
    UNION
    --application secondary type
    SELECT DISTINCT addr.countycode countycode, addr.countyname countyname,
                       ap.premcensustract premcensustract,
                       ap.basefileofficecodecorral district,
                       ap.basefileofficename, ap.licensenumber licensenumber,
                       OLT.licensetypecode licensetypecode,
                       OLT.licensetypename licensetypename,
                       LT.applicationstatus status,
                       DECODE (   DECODE (OLT.RETAILTYPE,
                                              'On-Sale', 'Y',
                                              'N'
                                         )
                               || DECODE (lt.applicationstatus,
                                          'PEND', 'N',
                                          'ISUSSED', 'N',
                                          'NEW', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) on_act_ind,
                       DECODE
                          (DECODE (   DECODE (OLT.RETAILTYPE,
                                              'On-Sale', 'Y',
                                              'N'
                                             )
                                   || DECODE (lt.applicationstatus,
                                              'PEND', 'N',
                                              'ISUSSED', 'N',
                                              'NEW', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) on_act_ind_num,
                       DECODE (   DECODE (OLT.RETAILTYPE,
                                              'Off-Sale', 'Y',
                                              'N'
                                         )
                               || DECODE (lt.applicationstatus,
                                          'PEND', 'N',
                                          'ISUSSED', 'N',
                                          'NEW', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) off_act_ind,
                       DECODE
                          (DECODE (   DECODE (OLT.RETAILTYPE,
                                              'Off-Sale', 'Y',
                                              'N'
                                             )
                                   || DECODE (lt.applicationstatus,
                                              'PEND', 'N',
                                              'ISUSSED', 'N',
                                              'NEW', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) off_act_ind_num,
                       CASE
                          WHEN OLT.RETAILTYPE = 'Off-Sale'
                             THEN 'Y'
                          ELSE 'N'
                       END off_pend_ind,
                       CASE
                          WHEN OLT.RETAILTYPE = 'On-Sale'
                             THEN 'Y'
                          ELSE 'N'
                       END on_pend_ind,

    --
                       DECODE
                          ((CASE
                               WHEN OLT.RETAILTYPE = 'Off-Sale'
                                  THEN 'Y'
                               ELSE 'N'
                            END
                           ),
                           'Y', 1,
                           0
                          ) off_pend_ind_num,
                       DECODE
                          ((CASE
                               WHEN OLT.RETAILTYPE = 'On-Sale'
                                  THEN 'Y'
                               ELSE 'N'
                            END
                           ),
                           'Y', 1,
                           0
                          ) on_pend_ind_num
    From QUERY.J_APPLICATION AP
    Join QUERY.R_APPPRIMARYLICENSETYPE RAL on RAL.APPLICATIONOBJECTID = AP.OBJECTID
    Join QUERY.O_PRIMARYLICENSETYPE LT on LT.OBJECTID = RAL.LICENSETYPEOBJECTID
    Join Query.R_PRILTLTCATSECONDARY RPS on RPS.PRIMARYLICENSETYPEOBJECTID = LT.OBJECTID
    Join QUERY.O_LICENSETYPECATEGORY OLT on OLT.OBJECTID = RPS.LICENSETYPECATEGORYOBJECTID
    join QUERY.R_APPLICATIONPREMADDR APA ON APA.APPLICATIONJOBID = AP.OBJECTID
    join QUERY.O_ADDRESS ADDR ON ADDR.OBJECTID = APA.ADDRESSOBJECTID
    where ( OLT.RETAILTYPE in ('On-Sale','Off-Sale' )
           or (OLT.LICENSETYPECODE in ('47','48','49') and LT.HASSECONDARY='Y')
           and AP.STATUSNAME in ('PEND','ISUSSED','NEW')
          )
    and ADDR.COUNTYCODE = a_county_code
    --and AP.LICENSENUMBER in (754220,753294,753857)
    UNION
    -----license primary types
    SELECT DISTINCT addr.countycode countycode,
                       UPPER (addr.countyname) countyname,
                       addr.censustract premcensustract,
                       l.basefileofficecodecorral district, l.basefileofficename,
                       l.licensenumber licensenumber,
                       lt.licensetypecode licensetypecode,
                       lt.licensetypename licensetypename, lt.statusname status,
                       DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                          'N'
                                         )
                               || DECODE (lt.statusname,
                                          'ACTIVE', 'Y',
                                          'SUSPEN', 'N',
                                          'AUTOREV', 'N',
                                          'HOLD', 'N',
                                          'SUREND', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) on_act_ind,
                       DECODE
                          (DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                              'N'
                                             )
                                   || DECODE (lt.statusname,
                                              'ACTIVE', 'Y',
                                              'SUSPEN', 'N',
                                              'AUTOREV', 'N',
                                              'HOLD', 'N',
                                              'SUREND', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) on_act_ind_num,
                       DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                          'N'
                                         )
                               || DECODE (lt.statusname,
                                          'ACTIVE', 'Y',
                                          'SUSPEN', 'N',
                                          'AUTOREV', 'N',
                                          'HOLD', 'N',
                                          'SUREND', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) off_act_ind,
                       DECODE
                          (DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale','Y',
                                              'N'
                                             )
                                   || DECODE (lt.statusname,
                                              'ACTIVE', 'Y',
                                              'SUSPEN', 'N',
                                              'AUTOREV', 'N',
                                              'HOLD', 'N',
                                              'SUREND', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) off_act_ind_num,
                       CASE
                          WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'Y'
                                AND DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'N'
                               )
                             THEN 'N'
                          WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'Y'
                                AND DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'N'
                               )
                             THEN 'N'
                          ELSE 'Y'
                       END off_pend_ind,
                       CASE
                          WHEN (   DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                      'N'
                                                     )
                                           || DECODE (lt.statusname,
                                                      'ACTIVE', 'Y',
                                                      'SUSPEN', 'N',
                                                      'AUTOREV', 'N',
                                                      'HOLD', 'N',
                                                      'SUREND', 'N',
                                                      'N'
                                                     ),
                                           'YY', 'Y',
                                           'N'
                                          ) = 'Y'
                                OR DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                      'N'
                                                     )
                                           || DECODE (lt.statusname,
                                                      'ACTIVE', 'Y',
                                                      'SUSPEN', 'N',
                                                      'AUTOREV', 'N',
                                                      'HOLD', 'N',
                                                      'SUREND', 'N',
                                                      'N'
                                                     ),
                                           'YY', 'Y',
                                           'N'
                                          ) = 'Y'
                                OR (CASE
                                       WHEN (    DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'Y'
                                             AND DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'N'
                                            )
                                          THEN 'N'
                                       WHEN (    DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'Y'
                                             AND DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'Off-Sale','Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'N'
                                            )
                                          THEN 'N'
                                       ELSE 'Y'
                                    END
                                   ) = 'Y'
                               )
                             THEN 'N'
                          ELSE 'Y'
                       END on_pend_ind,

                       --
                       DECODE
                          ((CASE
                               WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'Y'
                                     AND DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'N'
                                    )
                                  THEN 'N'
                               WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'Y'
                                     AND DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'N'
                                    )
                                  THEN 'N'
                               ELSE 'Y'
                            END
                           ),
                           'Y', 1,
                           0
                          ) off_pend_ind_num,
                       DECODE
                          ((CASE
                               WHEN (   DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                           'N'
                                                          )
                                                || DECODE (lt.statusname,
                                                           'ACTIVE', 'Y',
                                                           'SUSPEN', 'N',
                                                           'AUTOREV', 'N',
                                                           'HOLD', 'N',
                                                           'SUREND', 'N',
                                                           'N'
                                                          ),
                                                'YY', 'Y',
                                                'N'
                                               ) = 'Y'
                                     OR DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                           'N'
                                                          )
                                                || DECODE (lt.statusname,
                                                           'ACTIVE', 'Y',
                                                           'SUSPEN', 'N',
                                                           'AUTOREV', 'N',
                                                           'HOLD', 'N',
                                                           'SUREND', 'N',
                                                           'N'
                                                          ),
                                                'YY', 'Y',
                                                'N'
                                               ) = 'Y'
                                     OR (CASE
                                            WHEN (    DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale','Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'Y'
                                                  AND DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'N'
                                                 )
                                               THEN 'N'
                                            WHEN (    DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale',
                                                                 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'Y'
                                                  AND DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale',
                                                                 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'N'
                                                 )
                                               THEN 'N'
                                            ELSE 'Y'
                                         END
                                        ) = 'Y'
                                    )
                                  THEN 'N'
                               ELSE 'Y'
                            END
                           ),
                           'Y', 1,
                           0
                          ) on_pend_ind_num
    from QUERY.J_LICENSE l
    join QUERY.R_LICENSEADDRPREMISES raddr on RADDR.LICENSEJOBID = L.JOBID
    join QUERY.O_ADDRESS addr on ADDR.OBJECTID = RADDR.PREMISESOBJECTID
    join QUERY.R_LICENSELICENSETYPE llt on LLT.LICENSEJOBID = L.JOBID
    join QUERY.J_LICENSETYPE lt on LT.JOBID = LLT.LICENSETYPEJOBID
    join QUERY.R_LICENSETYPELTCATPRIMARY rltc on RLTC.LICENSETYPEJOBID = LT.OBJECTID
    join QUERY.O_LICENSETYPECATEGORY ltc on ltc.OBJECTID = RLTC.LICENSETYPECATEGORYOBJECTID
    where ( LTC.RETAILTYPE in ('Off-Sale','On-Sale')
           or (LT.LICENSETYPECODE in ('47','48','49') and LT.HASSECONDARY = 'Y' )
           and LT.STATUSNAME in ('ACTIVE','SUSPEN','AUTOREV','HOLD','SUREND')
          )
    and ADDR.COUNTYCODE = a_county_code
    --and L.LICENSENUMBER  in (753294,753857)
    -- license secondary type
    UNION
    SELECT DISTINCT addr.countycode countycode,
                       UPPER (addr.countyname) countyname,
                       addr.censustract premcensustract,
                       l.basefileofficecodecorral district, l.basefileofficename,
                       l.licensenumber licensenumber,
                       lt.licensetypecode licensetypecode,
                       lt.licensetypename licensetypename, lt.statusname status,
                       DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                          'N'
                                         )
                               || DECODE (lt.statusname,
                                          'ACTIVE', 'Y',
                                          'SUSPEN', 'N',
                                          'AUTOREV', 'N',
                                          'HOLD', 'N',
                                          'SUREND', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) on_act_ind,
                       DECODE
                          (DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                              'N'
                                             )
                                   || DECODE (lt.statusname,
                                              'ACTIVE', 'Y',
                                              'SUSPEN', 'N',
                                              'AUTOREV', 'N',
                                              'HOLD', 'N',
                                              'SUREND', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) on_act_ind_num,
                       DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                          'N'
                                         )
                               || DECODE (lt.statusname,
                                          'ACTIVE', 'Y',
                                          'SUSPEN', 'N',
                                          'AUTOREV', 'N',
                                          'HOLD', 'N',
                                          'SUREND', 'N',
                                          'N'
                                         ),
                               'YY', 'Y',
                               'N'
                              ) off_act_ind,
                       DECODE
                          (DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale','Y',
                                              'N'
                                             )
                                   || DECODE (lt.statusname,
                                              'ACTIVE', 'Y',
                                              'SUSPEN', 'N',
                                              'AUTOREV', 'N',
                                              'HOLD', 'N',
                                              'SUREND', 'N',
                                              'N'
                                             ),
                                   'YY', 'Y',
                                   'N'
                                  ),
                           'Y', 1,
                           0
                          ) off_act_ind_num,
                       CASE
                          WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'Y'
                                AND DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'N'
                               )
                             THEN 'N'
                          WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'Y'
                                AND DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                       'N'
                                                      )
                                            || DECODE (lt.statusname,
                                                       'ACTIVE', 'Y',
                                                       'SUSPEN', 'N',
                                                       'AUTOREV', 'N',
                                                       'HOLD', 'N',
                                                       'SUREND', 'N',
                                                       'N'
                                                      ),
                                            'YY', 'Y',
                                            'N'
                                           ) = 'N'
                               )
                             THEN 'N'
                          ELSE 'Y'
                       END off_pend_ind,
                       CASE
                          WHEN (   DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                      'N'
                                                     )
                                           || DECODE (lt.statusname,
                                                      'ACTIVE', 'Y',
                                                      'SUSPEN', 'N',
                                                      'AUTOREV', 'N',
                                                      'HOLD', 'N',
                                                      'SUREND', 'N',
                                                      'N'
                                                     ),
                                           'YY', 'Y',
                                           'N'
                                          ) = 'Y'
                                OR DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                      'N'
                                                     )
                                           || DECODE (lt.statusname,
                                                      'ACTIVE', 'Y',
                                                      'SUSPEN', 'N',
                                                      'AUTOREV', 'N',
                                                      'HOLD', 'N',
                                                      'SUREND', 'N',
                                                      'N'
                                                     ),
                                           'YY', 'Y',
                                           'N'
                                          ) = 'Y'
                                OR (CASE
                                       WHEN (    DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'Y'
                                             AND DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'N'
                                            )
                                          THEN 'N'
                                       WHEN (    DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'Y'
                                             AND DECODE
                                                    (   DECODE
                                                              (LTC.RETAILTYPE,'Off-Sale','Y',
                                                               'N'
                                                              )
                                                     || DECODE (lt.statusname,
                                                                'ACTIVE', 'Y',
                                                                'SUSPEN', 'N',
                                                                'AUTOREV', 'N',
                                                                'HOLD', 'N',
                                                                'SUREND', 'N',
                                                                'N'
                                                               ),
                                                     'YY', 'Y',
                                                     'N'
                                                    ) = 'N'
                                            )
                                          THEN 'N'
                                       ELSE 'Y'
                                    END
                                   ) = 'Y'
                               )
                             THEN 'N'
                          ELSE 'Y'
                       END on_pend_ind,

                       --
                       DECODE
                          ((CASE
                               WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'Y'
                                     AND DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'N'
                                    )
                                  THEN 'N'
                               WHEN (    DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale','Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'Y'
                                     AND DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                            'N'
                                                           )
                                                 || DECODE (lt.statusname,
                                                            'ACTIVE', 'Y',
                                                            'SUSPEN', 'N',
                                                            'AUTOREV', 'N',
                                                            'HOLD', 'N',
                                                            'SUREND', 'N',
                                                            'N'
                                                           ),
                                                 'YY', 'Y',
                                                 'N'
                                                ) = 'N'
                                    )
                                  THEN 'N'
                               ELSE 'Y'
                            END
                           ),
                           'Y', 1,
                           0
                          ) off_pend_ind_num,
                       DECODE
                          ((CASE
                               WHEN (   DECODE (   DECODE (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                           'N'
                                                          )
                                                || DECODE (lt.statusname,
                                                           'ACTIVE', 'Y',
                                                           'SUSPEN', 'N',
                                                           'AUTOREV', 'N',
                                                           'HOLD', 'N',
                                                           'SUREND', 'N',
                                                           'N'
                                                          ),
                                                'YY', 'Y',
                                                'N'
                                               ) = 'Y'
                                     OR DECODE (   DECODE (LTC.RETAILTYPE,'Off-Sale', 'Y',
                                                           'N'
                                                          )
                                                || DECODE (lt.statusname,
                                                           'ACTIVE', 'Y',
                                                           'SUSPEN', 'N',
                                                           'AUTOREV', 'N',
                                                           'HOLD', 'N',
                                                           'SUREND', 'N',
                                                           'N'
                                                          ),
                                                'YY', 'Y',
                                                'N'
                                               ) = 'Y'
                                     OR (CASE
                                            WHEN (    DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale','Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'Y'
                                                  AND DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'On-Sale', 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'N'
                                                 )
                                               THEN 'N'
                                            WHEN (    DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale',
                                                                 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'Y'
                                                  AND DECODE
                                                         (   DECODE
                                                                (LTC.RETAILTYPE,'Off-Sale',
                                                                 'Y',
                                                                 'N'
                                                                )
                                                          || DECODE
                                                                   (lt.statusname,
                                                                    'ACTIVE', 'Y',
                                                                    'SUSPEN', 'N',
                                                                    'AUTOREV', 'N',
                                                                    'HOLD', 'N',
                                                                    'SUREND', 'N',
                                                                    'N'
                                                                   ),
                                                          'YY', 'Y',
                                                          'N'
                                                         ) = 'N'
                                                 )
                                               THEN 'N'
                                            ELSE 'Y'
                                         END
                                        ) = 'Y'
                                    )
                                  THEN 'N'
                               ELSE 'Y'
                            END
                           ),
                           'Y', 1,
                           0
                          ) on_pend_ind_num
    from QUERY.J_LICENSE l
    join QUERY.R_LICENSEADDRPREMISES raddr on RADDR.LICENSEJOBID = L.JOBID
    join QUERY.O_ADDRESS addr on ADDR.OBJECTID = RADDR.PREMISESOBJECTID
    join QUERY.R_LICENSELICENSETYPE llt on LLT.LICENSEJOBID = L.JOBID
    join QUERY.J_LICENSETYPE lt on LT.JOBID = LLT.LICENSETYPEJOBID
    join QUERY.R_LICENSETYPELTCATSECONDARY rltc on RLTC.LICENSETYPEJOBID = LT.OBJECTID
    join QUERY.O_LICENSETYPECATEGORY ltc on ltc.OBJECTID = RLTC.LICENSETYPECATEGORYOBJECTID
    where ( LTC.RETAILTYPE in ('Off-Sale','On-Sale')
           or (LT.LICENSETYPECODE in ('47','48','49') and LT.HASSECONDARY = 'Y' )
           and LT.STATUSNAME in ('ACTIVE','SUSPEN','AUTOREV','HOLD','SUREND')
          )
     and ADDR.COUNTYCODE = a_county_code;

BEGIN

--delete table for a new set of data
DELETE FROM ABC.CENSUS_TRACT_COUNTY;

COMMIT;

FOR X IN c_license_ct LOOP
    BEGIN
        insert into ABC.CENSUS_TRACT_COUNTY
           (
              COUNTYCODE,
              COUNTYNAME,
              PREMCENSUSTRACT,
              DISTRICT,
              BASEFILEOFFICENAME,
              LICENSENUMBER,
              LICENSETYPECODE,
              LICENSETYPENAME,
              STATUS,
              ON_ACT_IND,
              ON_ACT_IND_NUM,
              OFF_ACT_IND,
              OFF_ACT_IND_NUM,
              OFF_PEND_IND,
              ON_PEND_IND,
              OFF_PEND_IND_NUM,
              ON_PEND_IND_NUM
           )
    values (
              X.COUNTYCODE,
              X.COUNTYNAME,
              X.PREMCENSUSTRACT,
              X.DISTRICT,
              X.BASEFILEOFFICENAME,
              X.LICENSENUMBER,
              X.LICENSETYPECODE,
              X.LICENSETYPENAME,
              X.STATUS,
              X.ON_ACT_IND,
              X.ON_ACT_IND_NUM,
              X.OFF_ACT_IND,
              X.OFF_ACT_IND_NUM,
              X.OFF_PEND_IND,
              X.ON_PEND_IND,
              X.OFF_PEND_IND_NUM,
              X.ON_PEND_IND_NUM
            );
    END;
END LOOP;

END;
/


GRANT EXECUTE ON ABC.PRO_CENSUS_TRACT_COUNTY TO POSSEEXTENSIONS;
