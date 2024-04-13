\cd 'C:/Users/Huang Licong/Desktop/2102'

\echo "Creating database..."
\i P02-DDL.sql
\echo "Database created."
\echo "Creating triggers and other functions..."
\i p.sql
\echo "Triggers and other functions created."
\echo "Inserting data..."
\i t.sql
\echo "Data inserted."


CALL add_car('Toyota', 'Camry1', 5, 1000.0, 50.0, ARRAY['ABC123'], ARRAY['White'], ARRAY[2020], ARRAY[12345]);