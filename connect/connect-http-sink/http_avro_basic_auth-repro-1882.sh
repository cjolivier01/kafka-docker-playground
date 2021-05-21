#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

${DIR}/../../environment/plaintext/start.sh "${PWD}/docker-compose.plaintext.yml"

# schema
# {
#     "fields": [
#         {
#             "name": "field1",
#             "type": "string"
#         },
#         {
#             "default": {
#                 "Currency": "EUR",
#                 "Value": 0
#             },
#             "doc": "field with a default value",
#             "name": "field2",
#             "type": {
#                 "fields": [
#                     {
#                         "name": "Value",
#                         "type": "float"
#                     },
#                     {
#                         "name": "Currency",
#                         "type": {
#                             "avro.java.string": "String",
#                             "type": "string"
#                         }
#                     }
#                 ],
#                 "name": "subfield2",
#                 "type": "record"
#             }
#         }
#     ],
#     "name": "MyRecord",
#     "namespace": "mynamespace",
#     "type": "record",
#     "version": 1
# }


log "Send message to topic myavrotopic1"
docker exec -i connect kafka-avro-console-producer --broker-list broker:9092 --property schema.registry.url=http://schema-registry:8081 --topic myavrotopic1 --property value.schema='{"fields":[{"name":"field1","type":"string"},{"default":{"Currency":"EUR","Value":0},"doc":"field with a default value","name":"field2","type":{"fields":[{"name":"Value","type":"float"},{"name":"Currency","type":{"avro.java.string":"String","type":"string"}}],"name":"subfield2","type":"record"}}],"name":"MyRecord","namespace":"mynamespace","type":"record","version":1}' << EOF
{"field1":"OOm","field2":{"Value":0.6223695,"Currency":"aa"}}
EOF

curl -X PUT \
     -H "Content-Type: application/json" \
     --data '{
          "topics": "myavrotopic1",
          "tasks.max": "1",
          "connector.class": "io.confluent.connect.http.HttpSinkConnector",
          "key.converter": "org.apache.kafka.connect.storage.StringConverter",
          "value.converter": "io.confluent.connect.avro.AvroConverter",
          "value.converter.schema.registry.url": "http://schema-registry:8081",
          "value.converter.enhanced.avro.schema.support": "true",
          "confluent.topic.bootstrap.servers": "broker:9092",
          "confluent.topic.replication.factor": "1",
          "reporter.bootstrap.servers": "broker:9092",
          "reporter.error.topic.name": "error-responses",
          "reporter.error.topic.replication.factor": 1,
          "reporter.result.topic.name": "success-responses",
          "reporter.result.topic.replication.factor": 1,
          "http.api.url": "http://http-service-basic-auth:8080/api/messages",
          "request.body.format": "json",
          "auth.type": "BASIC",
          "connection.user": "admin",
          "connection.password": "password"
          }' \
     http://localhost:8083/connectors/http-sink-1/config | jq .

sleep 4

curl localhost:8083/connectors/http-sink-1/status | jq
