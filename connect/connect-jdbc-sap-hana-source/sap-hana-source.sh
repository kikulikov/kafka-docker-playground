#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

if [ ! -f ${DIR}/ngdbc-2.12.9.jar ]
then
     log "Downloading ngdbc-2.12.9.jar "
     wget https://repo1.maven.org/maven2/com/sap/cloud/db/jdbc/ngdbc/2.12.9/ngdbc-2.12.9.jar
fi

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"


# Verify SAP HANA has started within MAX_WAIT seconds
MAX_WAIT=2500
CUR_WAIT=0
log "⌛ Waiting up to $MAX_WAIT seconds for SAP HANA to start"
docker container logs sap > /tmp/out.txt 2>&1
while [[ ! $(cat /tmp/out.txt) =~ "Startup finished!" ]]; do
sleep 10
docker container logs sap > /tmp/out.txt 2>&1
CUR_WAIT=$(( CUR_WAIT+10 ))
if [[ "$CUR_WAIT" -gt "$MAX_WAIT" ]]; then
     logerror "ERROR: The logs in sap container do not show 'Startup finished!' after $MAX_WAIT seconds. Please troubleshoot with 'docker container ps' and 'docker container logs'.\n"
     exit 1
fi
done
log "SAP HANA has started!"

log "Create table in SAP HANA"
docker exec -i sap /usr/sap/HXE/HDB90/exe/hdbsql -i 90 -d HXE -u LOCALDEV -p Localdev1  > /tmp/result.log  2>&1 <<-EOF
CREATE COLUMN TABLE CUSTOMERS(ID BIGINT NOT NULL GENERATED BY DEFAULT AS IDENTITY,FIRST_NAME VARCHAR(30),LAST_NAME VARCHAR(30));
INSERT INTO CUSTOMERS(FIRST_NAME,LAST_NAME) VALUES ('John','Doe');
EOF
cat /tmp/result.log

log "Creating SAP HANA JDBC Source connector"
curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
               "tasks.max": "1",
               "connector.class": "io.confluent.connect.jdbc.JdbcSourceConnector",
               "mode": "incrementing",
               "table.whitelist": "CUSTOMERS",
               "incrementing.column.name": "ID",
               "connection.url": "jdbc:sap://sap:39041/?databaseName=HXE&reconnect=true&statementCacheSize=512",
               "connection.user": "LOCALDEV",
               "connection.password" : "Localdev1",
               "topic.prefix": "sap-hana-"
          }' \
     http://localhost:8083/connectors/jdbc-sap-hana-source/config | jq .

sleep 5

log "Verifying topic sap-hana-CUSTOMERS"
timeout 60 docker exec connect kafka-avro-console-consumer -bootstrap-server broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic sap-hana-CUSTOMERS --from-beginning --max-messages 1

