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

-- Copy your solution here

CREATE OR REPLACE FUNCTION check_double_booked() RETURNS TRIGGER AS $$

BEGIN
  IF EXISTS (
    SELECT 1
    FROM Hires
    WHERE eid = NEW.eid
    AND bid != NEW.bid
    AND ((fromdate, todate) OVERLAPS (NEW.fromdate, NEW.todate)
    OR todate = NEW.fromdate
    OR fromdate = NEW.todate)

  ) THEN 
    RAISE EXCEPTION 'Overlapping booking';
  END IF;


  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER prevent_double_booking
BEFORE
INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_double_booked();


CREATE OR REPLACE FUNCTION check_car_double_booking()
RETURNS TRIGGER AS $$
DECLARE
  new_sdate DATE;
  new_days INT;
BEGIN
  SELECT sdate, days INTO new_sdate, new_days FROM Bookings WHERE bid = NEW.bid;

  IF EXISTS (
    SELECT 1 FROM Assigns A
    JOIN Bookings B on A.bid = B.bid
    WHERE A.plate = NEW.plate
    AND (B.sdate, B.sdate + B.days) OVERLAPS (new_sdate, new_sdate + new_days)
  ) THEN
    RAISE EXCEPTION 'Car is already booked during this period';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_car_double_booking
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE PROCEDURE check_car_double_booking();

-- During handover the employee must be located in the same location the booking is for
CREATE OR REPLACE FUNCTION check_employee_location()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM Employees E
    JOIN Bookings B ON E.zip = B.zip
    WHERE eid = NEW.eid 
    AND E.zip = B.zip
    AND B.bid = NEW.bid
  ) THEN
    RAISE EXCEPTION 'Employee must be located in the same location as the booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_employee_location
BEFORE INSERT ON Handover
FOR EACH ROW EXECUTE FUNCTION check_employee_location();


-- trigger5
-- The car assigned to the booking must be for the car models for the booking
-- Trigger on insertion into Assigns
-- When customer initiates a booking (id by bid), the customer selects a car model (identified by (brand, model))
-- When a car (CarDetails indentified by plate) is assigned to a booking after the booking is initiated, it must have the same (brand, model) as the booking

CREATE OR REPLACE FUNCTION check_car_model()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM CarDetails C
    JOIN Bookings B ON C.plate = NEW.plate
    WHERE B.bid = NEW.bid
    AND C.brand = B.brand
    AND C.model = B.model
    -- same model but different location
    AND C.zip = B.zip
  ) THEN
    RAISE EXCEPTION 'Car model does not match booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_car_model
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE FUNCTION check_car_model();

-- Driver must be hired within the start date and end date of a booking

CREATE OR REPLACE FUNCTION check_driver_hire()
RETURNS TRIGGER AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM Bookings B
    WHERE B.bid = NEW.bid
    AND New.fromdate >= B.sdate
    AND New.todate <= B.sdate + B.days
  ) THEN
    RAISE EXCEPTION 'Driver must be hired within the start date and end date of a booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_driver_hire
BEFORE INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_driver_hire();




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

-- Procedure 3

CREATE OR REPLACE PROCEDURE return_car (bid INT, eid INT) AS $$
-- add declarations here
DECLARE
  cost NUMERIC;
  days INT;
  daily NUMERIC;
  cbrand TEXT;
  cmodel TEXT;
  ccnum TEXT;
  deposit NUMERIC;
BEGIN
  -- CHECKS
  IF NOT EXISTS (
    SELECT 1
    FROM Bookings B
    WHERE B.bid = return_car.bid
  ) THEN
    RAISE EXCEPTION 'No booking with that bid exists';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM Employees E
    WHERE E.eid = return_car.eid
  ) THEN
    RAISE EXCEPTION 'No employee with that eid exists';
  END IF;

  -- LOGIC
  SELECT B.brand, B.model, B.days, B.ccnum INTO cbrand, cmodel, days, ccnum FROM Bookings B WHERE B.bid = return_car.bid;
  SELECT cm.daily, cm.deposit INTO daily, deposit FROM CarModels cm
  WHERE cm.brand = cbrand
  AND cm.model = cmodel;

  -- your code here
  cost := daily * days - deposit;
  INSERT INTO Returned (bid, eid, ccnum, cost)
  VALUES (bid, eid, ccnum, cost);
  IF cost > 0 AND ccnum IS NULL THEN
    RAISE EXCEPTION 'No ccnum provided';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 4

CREATE OR REPLACE PROCEDURE auto_assign () AS $$
DECLARE
  c CURSOR FOR (
    SELECT *
    FROM Bookings b
    WHERE b.bid NOT IN (
      SELECT bid
      FROM Assigns
    )
    ORDER BY b.bid ASC
  );
  r RECORD;
  brand TEXT;
  model TEXT;
  zip INT;
  sdate DATE;
  days INT;
  plate TEXT;
BEGIN
  OPEN c;
  LOOP
    FETCH c INTO r;
    EXIT WHEN NOT FOUND;
    SELECT cd.plate INTO plate
    FROM CarDetails cd
    WHERE cd.brand = r.brand
    AND cd.model = r.model
    AND cd.zip = r.zip
    AND NOT EXISTS (
      SELECT 1
      FROM Bookings b, Assigns a
      WHERE b.bid = a.bid
      AND a.plate = cd.plate
      AND (b.sdate, b.sdate + b.days + 1) OVERLAPS (r.sdate, r.sdate + r.days)
    )
    ORDER BY cd.plate ASC
    LIMIT 1;

    IF plate IS NOT NULL THEN
      INSERT INTO Assigns (bid, plate) VALUES (r.bid, plate);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;


