#!/bin/bash


APP_URL="http://localhost:8000"
LOG_FILE="health.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

response=$(curl -s -o /dev/null -w "%{http_code}" $APP_URL)

if [ "$response" == "200" ]; then
  echo "[$TIMESTAMP] OK - App is healthy" >> $LOG_FILE
else
  echo "[$TIMESTAMP] FAIL - Status code: $response" >> $LOG_FILE
fi