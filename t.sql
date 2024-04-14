-- initialize some entries 
INSERT INTO Customers (email, dob, address, phone, fsname, lsname) 
VALUES ('a@a.com', '2024-01-01', 'a', 80000000, 'a', 'a'); 
 
INSERT INTO Locations (zip, lname, laddr) 
VALUES (12345, 'a', 'a');
INSERT INTO Locations (zip, lname, laddr)
VALUES (12344, 'b', 'b');
 
INSERT INTO CarModels (brand, model, capacity, deposit, daily) 
VALUES ('Toyota', 'Camry', 5, 100, 10); 
 
INSERT INTO CarDetails (plate, color, pyear, brand, model, zip) 
VALUES ('ABC123', 'red', 2000, 'Toyota', 'Camry', 12345); 
 
INSERT INTO Employees (eid, ename, ephone, zip) 
VALUES (1, 'a', 80000000, 12345);
 
INSERT INTO Employees (eid, ename, ephone, zip)
VALUES (2, 'b', 80000000, 12344);
 
INSERT INTO Drivers (eid, pdvl) 
VALUES (1, 'a'); 
 
-- creating bookings 
 
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (1, '2024-01-03', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 
 
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (2, '2024-01-05', 1, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 
 
-- creating assignments 
 
INSERT INTO Assigns (bid, plate) 
VALUES (1, 'ABC123'); 
 
INSERT INTO Assigns (bid, plate) 
VALUES (2, 'ABC123'); 
 
-- creating hires 
 
INSERT INTO Hires (bid, eid, fromdate, todate, ccnum) 
VALUES (1, 1, '2024-01-03', '2024-01-05', '123456789'); 
 
INSERT INTO Hires (bid, eid, fromdate, todate, ccnum) 
VALUES (2, 1, '2024-01-05', '2024-01-06', '123456789'); 


-- Insert a new booking for car 'ABC123' from '2024-01-07' to '2024-01-09'
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (3, '2024-01-07', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

INSERT INTO Assigns (bid, plate) 
VALUES (3, 'ABC123'); 

-- Attempt to insert a new booking for car 'ABC123' that overlaps with the previous booking
-- This should raise an exception due to the check_car_double_booking() trigger
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (4, '2024-01-07', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

INSERT INTO Assigns (bid, plate) 
VALUES (4, 'ABC123'); 

-- Attempt to insert a new booking for car 'ABC123' that overlaps with the previous booking
-- This should raise an exception due to the check_car_double_booking() trigger
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (5, '2024-02-08', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

INSERT INTO Assigns (bid, plate) 
VALUES (5, 'ABC123'); 


-- Insert a new handover entry for booking 3 and employee 1
-- This should raise an exception due to the check_employee_location() trigger
INSERT INTO Handover (bid, eid)
VALUES (3, 2);

INSERT INTO Handover (bid, eid)
VALUES (3, 1);


-- Insert a new car model 'Toyota' 'supra' with capacity 2, deposit 200, and daily rate 20
INSERT INTO CarModels (brand, model, capacity, deposit, daily)
VALUES ('Toyota', 'supra', 2, 200, 20);

-- Insert a new car 'ABC122' with color 'blue', year 2005, brand 'Toyota', model 'supra', and location 12345
INSERT INTO CarDetails (plate, color, pyear, brand, model, zip)
VALUES ('ABC122', 'blue', 2000, 'Toyota', 'supra', 12345);

-- Insert to Assigns entry for bookings 4, brand 'Toyota', model 'supra' and plate 'ABC122'
-- This should raise an error as data not matching
INSERT INTO Assigns (bid, plate)
VALUES (4, 'ABC122');


-- Insert a new booking for car 'ABC123' from '2024-01-07' to '2024-01-09'
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (5, '2024-01-07', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

-- Insert a new hire for driver '1' from '2024-01-07' to '2024-01-09' for booking '5'
-- This should succeed because the hire dates overlap with the booking dates
INSERT INTO Hires (bid, eid, fromdate, todate, ccnum) 
VALUES (5, 1, '2024-01-07', '2024-01-09', '123456789'); 


-- Insert a new booking for car 'ABC123' from '2024-01-07' to '2024-01-09'
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (6, '2024-01-07', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

-- Attempt to insert a new hire for driver '1' from '2024-01-06' to '2024-01-08' for booking '5'
-- This should fail because the hire dates do not fully overlap with the booking dates
INSERT INTO Hires (bid, eid, fromdate, todate, ccnum) 
VALUES (6, 1, '2024-01-06', '2024-01-08', '123456789'); 


-- Insert a new booking for car 'ABC123' from '2024-01-07' to '2024-01-09'
INSERT INTO Bookings (bid, sdate, days, email, ccnum, bdate, brand, model, zip) 
VALUES (7, '2024-01-07', 3, 'a@a.com', '123456789', '2024-01-01', 'Toyota', 'Camry', 12345); 

-- Attempt to insert a new hire for driver '1' from '2024-01-08' to '2024-01-10' for booking '5'
-- This should fail because the hire dates do not fully overlap with the booking dates
INSERT INTO Hires (bid, eid, fromdate, todate, ccnum) 
VALUES (7, 1, '2024-01-08', '2024-01-10', '123456789'); 



