CREATE OR REPLACE FUNCTION SITESPECIFIC.NextBusinessDay (
  p_date DATE, 
  p_days_to_add NUMBER
) 
RETURN DATE
IS
  
  l_next_business_date DATE := p_date;
  l_days_to_add NUMBER := p_days_to_add;
  l_continue VARCHAR2(1) := 'Y' ;
  l_isHoliday NUMBER;

BEGIN

  WHILE l_Continue = 'Y' 
  LOOP
    l_next_business_date := l_next_business_date + l_days_to_add;
    SELECT COUNT(1) INTO l_isHoliday FROM API.HOLIDAYS WHERE HOLIDAY = l_next_business_date;  

    IF RTRIM(TO_CHAR( l_next_business_date, 'DAY')) NOT IN ('SATURDAY','SUNDAY') AND l_isHoliday = 0 THEN
      l_Continue :='N';
    ELSE
      l_days_to_add := 1;
    END IF;

  END LOOP;

  RETURN TRIM(l_next_business_date);
  
END;
/


GRANT EXECUTE ON SITESPECIFIC.NEXTBUSINESSDAY TO POSSEEXTENSIONS;
