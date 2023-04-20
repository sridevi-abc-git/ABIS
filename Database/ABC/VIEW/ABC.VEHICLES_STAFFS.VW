CREATE OR REPLACE FORCE VIEW ABC.VEHICLES_STAFFS
(VEHICLES_ID, VEHICLES_MAKE, VEHICLES_MODEL, VEHICLES_YEAR, VEHICLES_EQUIPMENT_NUMBER, 
 ASSIGNED, DRIVEN_DATE, COMMUTE_MILES, OPERATIONAL_MILES, JUSTIFICATION1, 
 JUSTIFICATION2, JUSTIFICATION3, JUSTIFICATION4, JUSTIFICATION5, JUSTIFICATION6, 
 V_COMMENTS, STAFF_ID, FIRST_NAME, LAST_NAME, PERSON_TYPE, 
 OFFICE_UNIT, PHONE_NUMBER, CELL_PHONE_NUMBER, S_COMMENTS)
BEQUEATH DEFINER
AS 
select
V.VEHICLES_ID,                                          
V.VEHICLES_MAKE,              
V.VEHICLES_MODEL,                
V.VEHICLES_YEAR,                 
V.VEHICLES_EQUIPMENT_NUMBER,                
V.ASSIGNED,                 
V.DRIVEN_DATE,                       
V.COMMUTE_MILES,                     
V.OPERATIONAL_MILES,                     
V.JUSTIFICATION1,                     
V.JUSTIFICATION2,                    
V.JUSTIFICATION3,                    
V.JUSTIFICATION4,                     
V.JUSTIFICATION5,                     
V.JUSTIFICATION6,                      
V.COMMENTS V_COMMENTS,
S.STAFF_ID,                     
S.FIRST_NAME,                
S.LAST_NAME,               
S.PERSON_TYPE,                
S.OFFICE_UNIT,               
S.PHONE_NUMBER,                
S.CELL_PHONE_NUMBER,                
S.COMMENTS S_COMMENTS 
from abc.vehicles v
join abc.staffs s on s.staff_id = v.staff_id;
