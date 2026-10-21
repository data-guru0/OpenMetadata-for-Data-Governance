-- NexaBank Customer Database (CRM + KYC)
-- Deliberately undocumented: no table/column comments, cryptic seg_cd column.
-- That is the "before governance" state students will fix in OpenMetadata.

CREATE SCHEMA crm;

CREATE TABLE crm.customers (
    customer_id    integer PRIMARY KEY,
    first_name     varchar(50)  NOT NULL,
    last_name      varchar(50)  NOT NULL,
    email          varchar(120),
    phone          varchar(30),
    date_of_birth  date,
    national_id    varchar(20),
    address_line   varchar(200),
    city           varchar(60),
    country        char(2),
    seg_cd         char(1),
    created_at     timestamp NOT NULL
);

CREATE TABLE crm.kyc_verifications (
    kyc_id           integer PRIMARY KEY,
    customer_id      integer NOT NULL REFERENCES crm.customers,
    document_type    varchar(20),
    document_number  varchar(30),
    status           varchar(10),
    pep_flag         boolean,
    sanctions_hit    boolean,
    verified_at      timestamp
);

-- Read-only account for OpenMetadata ingestion / profiler.
CREATE ROLE om_reader LOGIN PASSWORD 'om_reader_pw';
GRANT USAGE ON SCHEMA crm TO om_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA crm TO om_reader;
