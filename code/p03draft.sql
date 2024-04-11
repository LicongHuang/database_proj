--TRIGGERS - 
-- QUESTION 1
CREATE OR REPLACE FUNCTION check_driver_double_book()
RETURNS TRIGGER AS $$
BEGIN 
  IF EXISTS (
    SELECT 1 
    FROM Hires 
    Where eid = NEW.eid 
      AND (
        (NEW.fromdate BETWEEN HIRES.fromdate AND Hires.todate)
        OR (NEW.todate BETWEEN Hires.fromdate AND Hires.todate)
        OR (Hires.fromdate BETWEEN NEW.fromdate AND NEW.todate)
        OR (Hires.todate BETWEEN NEW.fromdate AND NEW.todate)
      )
  ) THEN 
    RAISE EXCEPTION 'Driver is double booked';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_driver_double_book
BEFORE INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_driver_double_book();


-- QUESTION 2
CREATE OR REPLACE FUNCTION check_car_double_book()
RETURNS TRIGGER AS $$
DECLARE
  bstart DATE;
  bend DATE;

BEGIN 
  SELECT b.sdate, (b.sdate+ b.days)
  INTO bstart, bend
  FROM Bookings b 
  WHERE b.bid = NEW.bid;

  IF EXISTS (
    SELECT 1
    FROM Assigns a
    JOIN Bookings b ON a.bid = b.bid
    WHERE a.bid = b.bid 
    AND a.plate = NEW.plate
    AND NOT (b.sdate + b.days < bstart OR b.sdate > bend)
    ) THEN 
      RAISE EXCEPTION 'car already booked.';
    END IF;
  RETURN NEW;
END;

$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_car_double_book
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE FUNCTION check_car_double_book();


-- QUESTION 3
CREATE TRIGGER trigger_check_driver_double_book
BEFORE INSERT ON Hires
FOR EACH ROW
EXECUTE FUNCTION check_driver_double_book();

CREATE OR REPLACE FUNCTION check_employee_pos_handover()
RETURNS TRIGGER AS $$
DECLARE 
  booking_location INT;
  employee_location INT;
BEGIN
-- zip for location
  SELECT zip INTO booking_location 
  FROM Bookings 
  WHERE bid = NEW.bid;

  SELECT zip INTO employee_location 
  FROM Employees 
  WHERE eid = NEW.eid;

  IF booking_location IS NULL OR employee_location is NULL or booking_location != employee_location 
  THEN
    RAISE EXCEPTION 'employee location does not match or invalid eid or invalid booking id';
  END IF;

  RETURN NEW;
end;
$$ language plpgsql;

CREATE TRIGGER trigger_check_employee_pos_handover
BEFORE INSERT ON Handover
FOR EACH ROW
EXECUTE FUNCTION check_employee_pos_handover();


-- QUESTION 4
CREATE OR REPLACE FUNCTION check_car_model()
RETURNS TRIGGER AS $$
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM CarDetails cd 
    JOIN Bookings b on b.brand = cd.brand AND b.model= cd.model
    WHERE cd.plate = NEW.plate AND b.bid = NEW.bid

  ) THEN 
    RAISE EXCEPTION 'CAR MODEL DOES NOT MATCH BOOKING REQUIREMENTS';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_car_model_before_assign
BEFORE INSERT ON Assigns 
FOR EACH ROW EXECUTE FUNCTION check_car_model();

-- QUESTION 5
CREATE OR REPLACE FUNCTION check_car_location_booking()
RETURNS TRIGGER AS $$
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM CarDetails cd, Bookings b 
    WHERE cd.zip = b.zip 
    AND cd.plate = NEW.plate
    AND b.bid = NEW.bid
  ) THEN 
    RAISE EXCEPTION 'Car not parked in same location as booking.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER check_car_location_before_assign
BEFORE INSERT ON Assigns
FOR EACH ROW EXECUTE FUNCTION check_car_location_booking();


-- QUESTION 6
CREATE OR REPLACE FUNCTION check_driver_start_end()
RETURNS TRIGGER AS $$
BEGIN 
  IF NOT EXISTS (
    SELECT 1 
    FROM Bookings b
    WHERE b.bid = NEW.bid
    AND NEW.fromdate >= b.sdate
    AND NEW.todate <= (b.sdate + b.days)
  ) THEN 
    RAISE EXCEPTION 'Driver hiring period not within start date and end date of booking';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_driver_start_end_before_insert_hires
BEFORE INSERT ON Hires
FOR EACH ROW EXECUTE FUNCTION check_driver_start_end();

-- PROCEDURES
-- QU 1
/*
-- Test data 
-- insert location first
INSERT INTO Locations (zip, lname, laddr) VALUES
(99999, 'TestLocation', '123 Test St');

DO $$
DECLARE
    test_eids INT[] := ARRAY[1, 2];
    test_enames TEXT[] := ARRAY['person1', 'person2'];
    test_ephones INT[] := ARRAY[91111111, 92222222];
    test_zips INT[] := ARRAY[99999, 99999];
    test_pdvls TEXT[] := ARRAY[NULL, 'PDVL1'];
BEGIN
    -- Call the add_employees procedure with the test data
    CALL add_employees(test_eids, test_enames, test_ephones, test_zips, test_pdvls);
END $$;

SELECT * FROM Employees;
*/

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

-- Qu 2
/*
INSERT INTO Locations (zip, lname, laddr) VALUES
(22222, 'TestLocation2', '1234 Test2 St');
CALL add_car(
    'Toyota', 
    'Corolla', 
    5, 
    500, 
    50, 
    ARRAY['ABC123', 'DEF456'], 
    ARRAY['Red', 'Blue'], 
    ARRAY[2018, 2019], 
    ARRAY[99999, 99999]
);
CALL add_car(
    'Honda', 
    'Civic', 
    4, 
    400, 
    40, 
    ARRAY[]::TEXT[], 
    ARRAY[]::TEXT[], 
    ARRAY[]::INT[], 
    ARRAY[]::INT[]
); 

SELECT * FROM CarModels;
SELECT * FROM CarDetails;
*/
-- PROCEDURE 2
CREATE OR REPLACE PROCEDURE add_car (
  brand   TEXT   , model  TEXT   , capacity INT  ,
  deposit NUMERIC, daily  NUMERIC,
  plates  TEXT[] , colors TEXT[] , pyears   INT[], zips INT[]
) AS $$
-- add declarations here
BEGIN
  -- your code here
  INSERT INTO CarModels(brand, model, capacity, deposit, daily)
  VALUES (brand, model, capacity, deposit, daily);

  IF array_length(plates,1) IS NOT NULL 
    THEN 
      FOR i IN 1..array_upper(plates,1) 
      LOOP
        INSERT INTO CarDetails(plate, color, pyear, brand, model, zip)
        VALUES (plates[i], colors[i], pyears[i], brand, model, zips[i]);
      END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 3
CREATE OR REPLACE PROCEDURE return_car (
  bid INT, eid INT, provccnum TEXT DEFAULT NULL
) AS $$
-- add declarations here
DECLARE 
  bookingccnum TEXT;
  v_bid INT := bid;
  computedcost NUMERIC;
BEGIN
  SELECT b.ccnum, (cm.daily * b.days) - cm.deposit
  INTO bookingccnum, computedcost 
  FROM Bookings b
  JOIN CarModels cm ON b.brand = cm.brand 
  AND b.model = cm.model
  WHERE b.bid = v_bid;

  IF provccnum IS NULL THEN
    provccnum := bookingccnum;
  END IF;

  IF computedcost > 0 AND provccnum IS NULL 
  THEN 
    RAISE EXCEPTION 'positve cost but no ccnum provided';

  END IF;
  computedcost := COALESCE(computedcost, 0);


  INSERT INTO Returned (bid, eid, cost, ccnum)
  VALUES (bid, eid, computedcost, provccnum);
END;
$$ LANGUAGE plpgsql;

-- PROCEDURE 4








