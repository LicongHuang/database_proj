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

-- PROCEDURE 1
CREATE OR REPLACE PROCEDURE add_employees (
  eids INT[], enames TEXT[], ephones INT[], zips INT[], pdvls TEXT[]
) AS $$
-- add declarations here
BEGIN
  -- your code here
END;
$$ LANGUAGE plpgsql;


-- PROCEDURE 2
CREATE OR REPLACE PROCEDURE add_car (
  brand   TEXT   , model  TEXT   , capacity INT  ,
  deposit NUMERIC, daily  NUMERIC,
  plates  TEXT[] , colors TEXT[] , pyears   INT[], zips INT[]
) AS $$
-- add declarations here
BEGIN
  -- your code here
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
DECLARE
  bookings_revenue NUMERIC := 0;
  drivers_revenue  NUMERIC := 0;
  car_details_cost NUMERIC := 0;
BEGIN
  -- revenue from bookings
  SELECT COALESCE(SUM(M.daily * B.days), 0) INTO bookings_revenue
  FROM Bookings B
  JOIN Assigns A ON B.bid = A.bid
  JOIN CarDetails C ON A.plate = C.plate -- car detail used in booking
  JOIN CarModels M ON C.brand = M.brand AND C.model = M.model -- car model used in booking
  WHERE NOT (B.sdate > edate OR B.sdate + B.days < sdate);

  -- revenue from drivers
  SELECT COALESCE(SUM((D.todate - D.fromdate + 1) * 10), 0) INTO drivers_revenue
  FROM Drivers D
  JOIN Hires H ON D.eid = H.eid
  WHERE NOT (H.fromdate > edate OR H.todate < sdate);

  -- cost from bookings
  SELECT COALESCE(COUNT(DISTINCT C.plate) * 100, 0) INTO car_details_cost
  FROM CarDetails C
  JOIN Assigns A ON C.plate = A.plate
  JOIN Bookings B ON A.bid = B.bid
  WHERE NOT (B.sdate > edate OR B.sdate + B.days < sdate);

  RETURN bookings_revenue + drivers_revenue - bookings_cost
END;
$$ LANGUAGE plpgsql;


-- FUNCTION 2
CREATE OR REPLACE FUNCTION top_n_location (
  n INT, sdate DATE, edate DATE
) RETURNS TABLE(lname TEXT, revenue NUMERIC, rank INT) AS $$
BEGIN
  RETURN QUERY
  WITH revenue_per_location AS (
    SELECT L.lname,
           COALESCE(SUM(M.daily * B.days), 0) 
           + COALESCE(SUM((D.todate - D.fromdate + 1) * 10), 0) 
           - COALESCE(COUNT(DISTINCT C.plate) * 100, 0) 
           AS revenue
    FROM Locations L
    LEFT JOIN CarDetails C ON L.zip = C.zip
    LEFT JOIN Assigns A ON C.plate = A.plate
    LEFT JOIN Bookings B ON A.bid = B.bid
    LEFT JOIN CarModels M ON C.brand = M.brand AND C.model = M.model
    LEFT JOIN Hires H ON B.bid = H.bid
    LEFT JOIN Drivers D ON H.eid = D.eid
    WHERE NOT (B.sdate > edate OR B.sdate + B.days < sdate)
    GROUP BY L.lname
  ),
  ranked_locations AS ( -- returns lname, revenue, rank
    SELECT R.lname, R.revenue, COUNT(DISTINCT R2.revenue) AS rank
    FROM revenue_per_location R, revenue_per_location R2
    WHERE R.revenue >= R2.revenue
    GROUP BY R.lname, R.revenue
  )
  SELECT lname, revenue, rank
  FROM ranked_locations
  WHERE rank <= n
  ORDER BY rank, lname;
END;
$$ LANGUAGE plpgsql;

