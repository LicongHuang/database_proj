/*
Group #
1. Name 1
  - Contribution A
  - Contribution B
2. Name 2
  - Contribution A
  - Contribution B
*/



/* Write your Trigger Below */


CREATE OR REPLACE FUNCTION check_double_booked() RETURNS TRIGGER AS $$
DECLARE
  overlapping BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM Hires
    WHERE eid = NEW.eid
    AND bid != NEW.bid
    AND (fromdate, todate) OVERLAPS (NEW.fromdate, NEW.todate)
    OR todate = NEW.fromdate
  ) INTO overlapping;

  IF overlapping THEN
    RAISE EXCEPTION 'Overlapping booking';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER prevent_double_booking
BEFORE
INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_double_booked();















/*
  Write your Routines Below
    Comment out your routine if you cannot complete
    the routine.
    If any of your routine causes error (even those
    that are incomplete), you may get 0 mark for P03.
*/
-- procedure 1 
CREATE OR REPLACE PROCEDURE add_employees (
  eids INT[], enames TEXT[], ephones INT[], zips INT[], pdvls TEXT[]
) AS $$
DECLARE
-- add declarations here
  i INT;
BEGIN
  FOR i IN 1..array_upper(eids, 1) 
  LOOP
    INSERT INTO Employees (eid, ename, ephone, zip)
    VALUES (eids[i], enames[i], ephones[i], zips[i]);

    IF pdvls[i] IS NOT NULL THEN
    INSERT INTO Drivers (eid, pdvl)
    VALUES (eids[i], pdvls[i]);

    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

--procedure 2
CREATE OR REPLACE PROCEDURE add_car (
  brand   TEXT   , model  TEXT   , capacity INT  ,
  deposit NUMERIC, daily  NUMERIC,
  plates  TEXT[] , colors TEXT[] , pyears   INT[], zips INT[]
) AS $$
DECLARE
  i INT;
BEGIN
  INSERT INTO CarModels (brand, model, capacity, deposit, daily)
  VALUES (brand, model, capacity, deposit, daily);
  IF array_length(plates, 1) IS NOT NULL THEN
  FOR i IN 1..array_length(plates, 1) LOOP
    INSERT INTO CarDetails (plate, color, pyear, brand, model, zip)
    VALUES (plates[i], colors[i], pyears[i], brand, model, zips[i]);
  END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;


-- PROCEDURE 3
CREATE OR REPLACE PROCEDURE return_car (
  bid INT, eid INT
) AS $$
-- add declarations here
BEGIN
  -- your code here
END;
$$ LANGUAGE plpgsql;


-- PROCEDURE 4
CREATE OR REPLACE PROCEDURE auto_assign () AS $$
-- add declarations here
BEGIN
  -- your code here
END;
$$ LANGUAGE plpgsql;


-- FUNCTION 1
CREATE OR REPLACE FUNCTION compute_revenue (
  sdate DATE, edate DATE
) RETURNS NUMERIC AS $$
  -- your code here
$$ LANGUAGE plpgsql;


-- FUNCTION 2
CREATE OR REPLACE FUNCTION top_n_location (
  n INT, sdate DATE, edate DATE
) RETURNS TABLE(lname TEXT, revenue NUMERIC, rank INT) AS $$
  -- your code here
$$ LANGUAGE plpgsql;
