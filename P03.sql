/*
Group 037
1. Huang Licong
  - Added triggers prevent_double_booking, prevent_car_double_booking, prevent_employee_location, prevent_car_model, prevent_driver_hire
  - Checked correctness of triggers against checker and added additional test cases
2. Tee Yu Xun
  - Added procedures add_employees, add_car
  - Checked correctness of procedures against checker and added additional test cases
3. Chow Yuan Jing
  - Added procedures return_car, auto_assign
  - Checked correctness of procedures against checker and added additional test cases
4. Low Bi Shen, Gary
  - Added functions compute_revenue, top_n_location, revenue_per_location (helper function for top_n_location)
  - Checked correctness of functions against checker and added additional test cases
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
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (compute_revenue.sdate, edate + 1);

  -- revenue from drivers
  SELECT COALESCE(SUM((H.todate - H.fromdate + 1) * 10), 0) INTO drivers_revenue
  FROM Hires H
  WHERE (H.fromdate, H.todate + 1) OVERLAPS (compute_revenue.sdate, edate + 1); -- +1 to include the last day to overlap

  -- cost from bookings
  SELECT COALESCE(COUNT(DISTINCT C.plate) * 100, 0) INTO car_details_cost
  FROM CarDetails C
  JOIN Assigns A ON C.plate = A.plate
  JOIN Bookings B ON A.bid = B.bid
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (compute_revenue.sdate, edate + 1);

  RAISE NOTICE 'bookings_revenue: %', bookings_revenue;
  RAISE NOTICE 'drivers_revenue: %', drivers_revenue;
  RAISE NOTICE 'car_details_cost: %', car_details_cost;
  RAISE NOTICE 'net revenue: %', bookings_revenue + drivers_revenue - car_details_cost;

  RETURN bookings_revenue + drivers_revenue - car_details_cost;
END;
$$ LANGUAGE plpgsql;


-- FUNCTION 2
-- FUNCTION 2
CREATE OR REPLACE FUNCTION top_n_location (
  n INT, sdate DATE, edate DATE
) RETURNS TABLE(lname TEXT, revenue NUMERIC, rank INT) AS $$
BEGIN
  RETURN QUERY
  WITH rev_per_loc AS (
    SELECT 
      zip, 
      Locations.lname,
      revenue_per_location(zip, sdate, edate) AS revenue
    FROM Locations
  ), location_rankings AS (
    SELECT
      rev_of_curr_loc.lname AS lr_lname,
      rev_of_curr_loc.revenue AS lr_revenue,
      CAST(
        (
          SELECT COUNT(*) 
          FROM rev_per_loc AS other_locations_rev
          WHERE other_locations_rev.revenue >= rev_of_curr_loc.revenue
        ) AS INTEGER 
      ) AS lr_rank
    FROM rev_per_loc AS rev_of_curr_loc
  )
  SELECT lr_lname AS lname, lr_revenue AS revenue, lr_rank AS rank
  FROM (
    SELECT lr_lname, lr_revenue, lr_rank,
           DENSE_RANK() OVER (ORDER BY lr_rank, lr_lname) AS dense_rank
    FROM location_rankings
  ) AS ranked_locations
  WHERE lr_rank <= n
  ORDER BY lr_rank, lr_lname;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION revenue_per_location (
  location_zip INT,
  start_date DATE,
  end_date DATE
) RETURNS NUMERIC AS $$
DECLARE
  bookings_revenue NUMERIC := 0;
  drivers_revenue NUMERIC := 0;
  car_details_cost NUMERIC := 0;
BEGIN
  -- Calculate revenue from bookings
  SELECT COALESCE(SUM(M.daily * B.days), 0) INTO bookings_revenue
  FROM Bookings B
  JOIN Assigns A ON B.bid = A.bid
  JOIN CarDetails C ON A.plate = C.plate
  JOIN CarModels M ON C.brand = M.brand AND C.model = M.model
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (start_date, end_date + 1)
    AND C.zip = location_zip;

  -- Calculate revenue from drivers
  SELECT COALESCE(SUM((H.todate - H.fromdate + 1) * 10), 0) INTO drivers_revenue
  FROM Hires H
  JOIN Assigns A ON H.bid = A.bid
  JOIN CarDetails C ON A.plate = C.plate
  WHERE (H.fromdate, H.todate + 1) OVERLAPS (start_date, end_date + 1)
    AND C.zip = location_zip;

  -- Calculate cost from bookings
  SELECT COALESCE(COUNT(DISTINCT C.plate) * 100, 0) INTO car_details_cost
  FROM CarDetails C
  JOIN Assigns A ON C.plate = A.plate
  JOIN Bookings B ON A.bid = B.bid
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (start_date, end_date + 1)
    AND C.zip = location_zip;

  -- Return the net revenue
  RETURN bookings_revenue + drivers_revenue - car_details_cost;
END;
$$ LANGUAGE plpgsql;