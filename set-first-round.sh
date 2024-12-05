#!/bin/bash

# Ensure the script stops on the first error
set -e

# Load environment variables from .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | sed 's/\r$//' | xargs)
else
    echo "ERROR: .env file not found"
    exit 1
fi

# Verify required environment variables
if [ -z "$FOSSIL_API_KEY" ]; then
    echo "ERROR: FOSSIL_API_KEY not set in .env file"
    exit 1
fi

FOSSILCLIENT_ADDRESS=0x04a79841d82dc71f8980faf48be940013e97f59c49856e70a15e45f237fa7f99
VAULT_ADDRESS=0x0473c4b091ba7c9afacab4d8f4cf5bbd5ba0a5e7bebee98fcd3d80564ac00935

ONE_MONTH_SECONDS=2592000
ONE_WEEK_SECONDS=604800

# Get request to settle round
REQUEST_DATA=$(starkli call $VAULT_ADDRESS get_request_to_start_first_round)
echo "Settlement request data: $REQUEST_DATA"

# Format request for Fossil API
# The request data contains [id, vault_address, timestamp, program_id]
VAULT_ADDRESS=$(echo $REQUEST_DATA | jq -r '.[1]')
TIMESTAMP_HEX=$(echo $REQUEST_DATA | jq -r '.[2]')
IDENTIFIER=$(echo $REQUEST_DATA | jq -r '.[3]')
# Convert hex timestamp to decimal (strip 0x and convert)
TIMESTAMP=$((16#${TIMESTAMP_HEX#0x}))

TWAP_FROM=$(($TIMESTAMP - $ONE_MONTH_SECONDS))
VOLATILITY_FROM=$(($TIMESTAMP - $ONE_WEEK_SECONDS))
RESERVE_PRICE_FROM=$(($TIMESTAMP - $ONE_MONTH_SECONDS))

echo "Current time: $(date -r $TIMESTAMP)"
echo "TWAP from: $(date -r $TWAP_FROM)"
echo "Volatility from: $(date -r $VOLATILITY_FROM)" 
echo "Reserve price from: $(date -r $RESERVE_PRICE_FROM)"

echo "Decoded request data:"
echo "Vault address: $VAULT_ADDRESS"
echo "Timestamp: $TIMESTAMP"
echo "Identifier: $IDENTIFIER"

FOSSIL_RESPONSE=$(curl -X POST "http://localhost:3000/pricing_data" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $FOSSIL_API_KEY" \
    -d "{
        \"identifiers\":[\"$IDENTIFIER\"],
        \"params\": {
            \"twap\": [$TWAP_FROM, $TIMESTAMP], 
            \"volatility\": [$VOLATILITY_FROM, $TIMESTAMP],
            \"reserve_price\": [$RESERVE_PRICE_FROM, $TIMESTAMP]
        },
        \"client_info\": {
            \"client_address\": \"$FOSSILCLIENT_ADDRESS\",
            \"vault_address\": \"$VAULT_ADDRESS\",
            \"timestamp\": $TIMESTAMP
        }
    }")

echo "Fossil response: $FOSSIL_RESPONSE"
JOB_ID=$(echo $FOSSIL_RESPONSE | jq -r '.job_id')
echo "Fossil job ID: $JOB_ID"

# Poll Fossil status endpoint until request is fulfilled
while true; do
    echo "Polling Fossil request status..."
    STATUS_RESPONSE=$(curl -s "http://localhost:3000/job_status/$JOB_ID")
    STATUS=$(echo $STATUS_RESPONSE | jq -r '.status')
    echo "Fossil status: $STATUS"
    
    if [ "$STATUS" = "Completed" ]; then
        echo "Request fulfilled by Fossil"
        break
    elif [ "$STATUS" = "Failed" ]; then
        echo "ERROR: Fossil request failed"
        echo "Response: $STATUS_RESPONSE"
        exit 1
    fi
    
    sleep 10
done