-- The 'orders' database is created by POSTGRES_DB env var
-- This script creates catalogdb, cartdb and grants permissions

CREATE DATABASE catalogdb;
CREATE DATABASE cartdb;

GRANT ALL PRIVILEGES ON DATABASE catalogdb TO retail_user;
GRANT ALL PRIVILEGES ON DATABASE cartdb TO retail_user;
GRANT ALL PRIVILEGES ON DATABASE orders TO retail_user;

\c orders
GRANT ALL ON SCHEMA public TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO retail_user;

\c catalogdb
GRANT ALL ON SCHEMA public TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO retail_user;

\c cartdb
GRANT ALL ON SCHEMA public TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO retail_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO retail_user;

CREATE TABLE cart_items (
    customer_id VARCHAR(255) NOT NULL,
    item_id     VARCHAR(255) NOT NULL,
    quantity    INTEGER      NOT NULL,
    unit_price  INTEGER      NOT NULL,
    PRIMARY KEY (customer_id, item_id)
);
