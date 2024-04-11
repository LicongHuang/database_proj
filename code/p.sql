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
  ) THEN
    RAISE EXCEPTION 'Employee must be located in the same location as the booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_employee_location
BEFORE INSERT ON Handover
FOR EACH ROW EXECUTE FUNCTION check_employee_location();


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
    FROM Hires H
    JOIN Bookings B ON H.bid = B.bid
    WHERE H.eid = NEW.eid
    AND H.fromdate >= B.sdate
    AND H.todate <= B.sdate + B.days
  ) THEN
    RAISE EXCEPTION 'Driver must be hired within the start date and end date of a booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_driver_hire
BEFORE INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_driver_hire();


CREATE OR REPLACE PROCEDURE add_employees (
  eids INT[], enames TEXT[], ephones INT[], zips INT[], pdvls TEXT[]
) AS $$
DECLARE
  i INT;
BEGIN
  FOR i IN 1..array_length(eids, 1) LOOP
    INSERT INTO Employees (eid, ename, ephone, zip) 
    VALUES (eids[i], enames[i], ephones[i], zips[i]);

    IF pdvls[i] IS NOT NULL THEN
      INSERT INTO Drivers (eid, pdvl) 
      VALUES (eids[i], pdvls[i]);
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 2
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

  FOR i IN 1..array_length(plates, 1) LOOP
    INSERT INTO CarDetails (plate, color, pyear, brand, model, zip)
    VALUES (plates[i], colors[i], pyears[i], brand, model, zips[i]);
  END LOOP;

END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 3


-- CREATE OR REPLACE PROCEDURE return_car (
--   bid INT, eid INT
-- ) AS $$
-- DECLARE
--   plate TEXT; cost NUMERIC;
--   ccnum TEXT; days INT;
--   deposit NUMERIC; daily NUMERIC;
-- BEGIN
--   SELECT A.plate, B.days, B.deposit, B.daily, BK.ccnum 
--   INTO plate, days, deposit, daily, ccnum
--   FROM Assigns A
--   JOIN Bookings B ON A.bid = B.bid
--   JOIN Bookings BK ON A.bid = BK.bid
--   WHERE A.bid = bid;
-- 
--   cost := daily * days + deposit ;
-- 
-- 
--   INSERT INTO Returned (bid, eid, ccnum, cost)
--   VALUES (bid, eid, plate, ccnum, cost);
-- 
-- END;
-- $$ LANGUAGE plpgsql;


-- Find all bookings without assigned car details
-- Sort the bookings found in Step a in ascending order of the bid
-- Sort all car details in ascending order of plate
-- Starting from the smallest booking bid, assing the car with the smallest plate that satisfies it booking requirement

-- Recap booking requirements:
-- 1. The brand and model match
-- 2. The location identified by zip match
-- 3. The car is not double booked
-- -- Note that we may auto assign the same car multiple times as we assume the car will be returned on time






