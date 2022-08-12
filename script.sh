#!/bin/bash
set -e

docker-compose down
rm -Rf ./data
docker-compose up -d

sleep 10

echo 'create example table'
docker-compose exec clickhouse-server clickhouse-client  --multiquery --multiline --query "
CREATE DATABASE IF NOT EXISTS example_db;

CREATE TABLE IF NOT EXISTS example_db.customers(
    id INTEGER,
    first_name String,
    last_name String,
    email String,
    orders_num INTEGER
) ENGINE = MergeTree()
PRIMARY KEY id;

INSERT INTO example_db.customers VALUES (1,'Sally','Thomas','sally.thomas@acme.com', 1);
"

echo 'added rows'
docker-compose exec -T clickhouse-server clickhouse-client -q "select * from example_db.customers order by id desc"

echo 'create replica'
docker-compose exec clickhouse-server clickhouse-client  --multiquery --multiline --query "
CREATE DATABASE IF NOT EXISTS replica_db;

CREATE TABLE IF NOT EXISTS replica_db.customers(
    id INTEGER,
    first_name String,
    last_name String,
    email String,
    orders_num INTEGER,
    _sign INTEGER,
    _version INTEGER
) ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/example_db.customers', '{replica}')
PRIMARY KEY id;
"

echo 'add some data'
docker-compose exec clickhouse-server clickhouse-client  --multiline -q "
INSERT INTO example_db.customers (id, first_name, last_name, email, orders_num) VALUES
       (2,'Edward','Walker','ed@walker.com', 3),
       (3,'Anne','Kretchmar','annek@noanswer.org', 4),
       (4,'Anne','Walker','anne@walker.org', 2);
"
echo 'example_db data'
docker-compose exec -T clickhouse-server clickhouse-client -q "select * from example_db.customers order by id desc"
echo 'replica_db data'
docker-compose exec -T clickhouse-server clickhouse-client -q "select * from replica_db.customers order by id desc"
