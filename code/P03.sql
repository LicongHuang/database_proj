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
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (compute_revenue.sdate, edate);

  -- revenue from drivers
  SELECT COALESCE(SUM((H.todate - H.fromdate + 1) * 10), 0) INTO drivers_revenue
  FROM Hires H
  WHERE (H.fromdate, H.todate + 1) OVERLAPS (compute_revenue.sdate, edate); -- +1 to include the last day to overlap

  -- cost from bookings
  SELECT COALESCE(COUNT(DISTINCT C.plate) * 100, 0) INTO car_details_cost
  FROM CarDetails C
  JOIN Assigns A ON C.plate = A.plate
  JOIN Bookings B ON A.bid = B.bid
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (compute_revenue.sdate, edate);

  RETURN bookings_revenue + drivers_revenue - car_details_cost;
END;
$$ LANGUAGE plpgsql;

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
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (start_date, end_date)
    AND C.zip = location_zip;

  -- Calculate revenue from drivers
  SELECT COALESCE(SUM((H.todate - H.fromdate + 1) * 10), 0) INTO drivers_revenue
  FROM Hires H
  JOIN Assigns A ON H.bid = A.bid
  JOIN CarDetails C ON A.plate = C.plate
  WHERE (H.fromdate, H.todate + 1) OVERLAPS (start_date, end_date)
    AND C.zip = location_zip;

  -- Calculate cost from bookings
  SELECT COALESCE(COUNT(DISTINCT C.plate) * 100, 0) INTO car_details_cost
  FROM CarDetails C
  JOIN Assigns A ON C.plate = A.plate
  JOIN Bookings B ON A.bid = B.bid
  WHERE (B.sdate, B.sdate + B.days) OVERLAPS (start_date, end_date)
    AND C.zip = location_zip;

  -- Return the net revenue
  RETURN bookings_revenue + drivers_revenue - car_details_cost;
END;
$$ LANGUAGE plpgsql;
