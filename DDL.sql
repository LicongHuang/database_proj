DROP TABLE IF EXISTS Hires      CASCADE;
DROP TABLE IF EXISTS Returned   CASCADE;
DROP TABLE IF EXISTS Handover   CASCADE;
DROP TABLE IF EXISTS Assigns    CASCADE;
DROP TABLE IF EXISTS Bookings   CASCADE;
DROP TABLE IF EXISTS CarDetails CASCADE;
DROP TABLE IF EXISTS CarModels  CASCADE;
DROP TABLE IF EXISTS Drivers    CASCADE;
DROP TABLE IF EXISTS Employees  CASCADE;
DROP TABLE IF EXISTS Locations  CASCADE;
DROP TABLE IF EXISTS Customers  CASCADE;

CREATE TABLE Customers (
  email     TEXT  PRIMARY KEY, -- as stated, no need to use CHECK on email
  dob       DATE  NOT NULL CHECK (dob < NOW()), -- check may be omitted
  address   TEXT  NOT NULL,
  phone     INT   CHECK (phone >= 80000000 AND phone <= 99999999), -- if SG, but not needed
  fsname    TEXT  NOT NULL,
  lsname    TEXT  NOT NULL
  -- name is composite and need not be present
  -- age is derived and need not be present
);

CREATE TABLE Locations (
  zip       INT   PRIMARY KEY,
  lname     TEXT  NOT NULL UNIQUE,
  laddr     TEXT  NOT NULL
  -- alternatively, we can also set
  /*
  zip       INT   NOT NULL UNIQUE,
  lname     TEXT  PRIMARY KEY,
  */
  -- but we need to change ALL
  --    references to Locations
);

-- Merged with Works
CREATE TABLE Employees (
  eid       INT   PRIMARY KEY,
  ename     TEXT  NOT NULL,
  ephone    INT   CHECK (ephone >= 80000000 AND ephone <= 99999999), -- if SG, but not needed
  -- Employees ==> Works
  zip       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Locations (zip)
);

-- no need to enforce Employees --> {Drivers}
--    as it is, in a way, automatically enforced
CREATE TABLE Drivers (
  eid       INT   PRIMARY KEY
    REFERENCES Employees (eid)
    ON UPDATE CASCADE  -- not vital 
    ON DELETE CASCADE, -- not vital
  pdvl      TEXT  NOT NULL UNIQUE
  -- pdvl should NOT be the PK
  --    to keep the semantics clear
  --    that it inherits from Employees
  --    i.e., same PK as Employees
);

CREATE TABLE CarModels (
  brand     TEXT,
  model     TEXT,
  capacity  INT     NOT NULL CHECK (capacity > 0), -- real-world constraint
  deposit   NUMERIC NOT NULL CHECK (deposit > 0),  -- real-world constraint
  daily     NUMERIC NOT NULL CHECK (daily > 0),    -- real-world constraint
  PRIMARY KEY (brand, model)
);

-- Merged with DetailsFor and Parks
CREATE TABLE CarDetails (
  plate     TEXT  PRIMARY KEY,
  color     TEXT  NOT NULL,
  pyear     INT   CHECK(pyear > 1900), -- when's the first car?  also, optional chck
  -- Alternatively, use DATE
  -- CarDetails ==> DetailsFor
  brand     TEXT  NOT NULL, -- IMPORTANT NOT NULL!
  model     TEXT  NOT NULL, -- IMPORTANT NOT NULL!
  -- CarDetails ==> Parks
  zip       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Locations (zip),
  FOREIGN KEY (brand, model) REFERENCES CarModels (brand, model)
);

-- Merged with Initiates, Rents, and For
CREATE TABLE Bookings (
  bid       INT   PRIMARY KEY,
  sdate     DATE  NOT NULL,
  days      INT   NOT NULL CHECK (days > 0),
  -- edate is derived and need not be present
  -- Bookings ==> Initiates
  email     TEXT  NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Customers (email),
  ccnum     TEXT  NOT NULL,
  bdate     DATE  NOT NULL CHECK (bdate < sdate),
  -- Bookings ==> Rents (FK below)
  brand     TEXT  NOT NULL, -- IMPORTANT NOT NULL!
  model     TEXT  NOT NULL, -- IMPORTANT NOT NULL!
  -- Bookings ==> For
  zip       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Locations (zip),
  -- FK for Bookings ==> Rents
  FOREIGN KEY (brand, model) REFERENCES CarModels (brand, model)
);

-- Can also be merged with Bookings
--    but it is easier if separated
--    otherwise, Bookings is too big
CREATE TABLE Assigns (
  bid       INT   PRIMARY KEY
    REFERENCES Bookings (bid),
  plate     TEXT  NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES CarDetails (plate)
);

-- Can also be merged with Assigns
--    but it is easier if separated
CREATE TABLE Handover (
  bid       INT   PRIMARY KEY
    REFERENCES Assigns (bid),
  eid       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Employees (eid)
);

-- Can also be merged with Assigns
--    but it is easier if separated
-- It is also not necessary to reference
--    Handover due to the ER diagram
--    kudos to those who reference Handover
-- It is accepted to just reference
--    Assigns
CREATE TABLE Returned (
  bid       INT   PRIMARY KEY
    REFERENCES Handover (bid),
  eid       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Employees (eid),
  -- ccnum is required in return if
  --   the cost is positive, the logic
  --   is as follows
  -- (cost > 0)  ->  (ccnum IS NOT NULL)
  --   it can be translated to
  -- (cost <= 0) OR  (ccnum IS NOT NULL)
  ccnum     TEXT  CHECK (cost <= 0 OR ccnum IS NOT NULL), -- from constraint
  cost      NUMERIC   NOT NULL
  -- Cannot add a check that cost > 0 here
  --    because it really can be negative
  -- NOTE: cost should be ((daily * num_days) - deposit)
  --       this is not in P02.docx and
  --       requires triggers to check
);

-- Can also be merged with Assigns
--    but it is easier if separated
CREATE TABLE Hires (
  bid       INT   PRIMARY KEY
    REFERENCES Assigns (bid),
  eid       INT   NOT NULL  -- IMPORTANT NOT NULL!
    REFERENCES Drivers (eid),
  fromdate  DATE  NOT NULL,
  todate    DATE  NOT NULL CHECK (todate >= fromdate), -- real-world constraint
  ccnum     TEXT  NOT NULL
);

/*
Additional Notes
- ID cannot be FLOAT/DOUBLE
  can be TEXT/INT/BIGINT/SERIAL
  NUMERIC is still potentially bad
- Monetary values must be either NUMERIC/MONEY
  cannot be FLOAT/DOUBLE
  see: https://thisisadi.yoga/cs2102/slides/L02.html#17
- Dates are minimally DATE but can also be TIMESTAMP
  just need to be careful if using TIMESTAMP
- pyear can be either INT or DATE
  just need to be careful if using DATE
- ON UPDATE/DELETE CASCADE is only required for weak entity set
  no penalty for missing or adding
*/