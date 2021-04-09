#!/bin/sh

echo 'Configuring Oracle for user myuser'

# Set archive log mode and enable GG replication
ORACLE_SID=ORCLCDB
export ORACLE_SID

# Create test user
sqlplus sys/Admin123@//localhost:1521/ORCLPDB1 as sysdba <<- EOF
	CREATE USER myuser IDENTIFIED BY mypassword;
	GRANT CONNECT TO myuser;
	GRANT CREATE SESSION TO myuser;
	GRANT CREATE TABLE TO myuser;
	GRANT CREATE SEQUENCE TO myuser;
	GRANT CREATE TRIGGER TO myuser;
	ALTER USER myuser QUOTA 100M ON users;

	-- for mtls test
	CREATE USER sslclient IDENTIFIED EXTERNALLY AS 'CN=connect,C=US';
	GRANT CONNECT TO sslclient;
	GRANT CREATE SESSION TO sslclient;
	GRANT CREATE TABLE TO sslclient;
	GRANT CREATE SEQUENCE TO sslclient;
	GRANT CREATE TRIGGER TO sslclient;
	ALTER USER sslclient QUOTA 100M ON users;

	exit;
EOF
