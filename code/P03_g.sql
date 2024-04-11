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
DECLARE
  r RECORD;
  cost NUMERIC;
BEGIN
  SELECT * INTO r
  FROM Bookings B
  JOIN CarModels M ON B.brand = M.brand AND B.model = M.model
  WHERE B.bid = bid;

  cost := (r.daily * r.days) - r.deposit;

  INSERT INTO Returned (bid, eid, ccnum, cost) VALUES (bid, eid, r.ccnum, cost);
END;
$$ LANGUAGE plpgsql;


-- PROCEDURE 4
CREATE OR REPLACE PROCEDURE auto_assign () AS $$
DECLARE
  booking_curs CURSOR FOR ( -- a
    SELECT *
    FROM Bookings B
    WHERE NOT EXISTS (
      SELECT 1 FROM Assigns A WHERE A.bid = B.bid
    )
    ORDER BY B.bid ASC; -- b
  );
  r RECORD;
  car_plate TEXT;
BEGIN
  prev_bid := -1;
  OPEN booking_curs;
  LOOP
    FETCH booking_curs INTO r;
    EXIT WHEN NOT FOUND;
    -- c
    SELECT C.plate INTO car_plate
    FROM CarDetails C
    WHERE C.brand = r.brand AND C.model = r.model AND C.zip = r.zip
    AND NOT EXISTS ( -- not double booked
      SELECT 1 
      FROM Assigns A
      JOIN Bookings B ON A.bid = B.bid
      WHERE A.plate = C.plate
      AND NOT (B.sdate > r.sdate + r.days OR B.sdate + B.days < r.sdate) -- overlapping
    )
    ORDER BY C.plate ASC
    LIMIT 1;

    -- d
    IF car_plate IS NOT NULL THEN
      INSERT INTO Assigns (bid, plate) VALUES (r.bid, car_plate);
    END IF;
  END LOOP;
  CLOSE booking_curs;
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
