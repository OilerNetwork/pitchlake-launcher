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

if [ -z "$FOSSILCLIENT_ADDRESS" ]; then
    echo "ERROR: FOSSILCLIENT_ADDRESS not set in .env file"
    exit 1
fi

if [ -z "$VAULT_ADDRESS" ]; then
    echo "ERROR: VAULT_ADDRESS not set in .env file"
    exit 1
fi

echo "Testing round transitions for vault at $VAULT_ADDRESS"

# Get current round ID and extract the value from the array
CURRENT_ROUND_ID=$(starkli call $VAULT_ADDRESS get_current_round_id | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
echo "Current round ID: $CURRENT_ROUND_ID"

# Get current round address using the extracted value and extract address from array
CURRENT_ROUND=$(starkli call $VAULT_ADDRESS get_round_address $CURRENT_ROUND_ID | grep -o '0x[0-9a-f]*' | head -1)
echo "Current round address: $CURRENT_ROUND"

# Get current round state
ROUND_STATE=$(starkli call $CURRENT_ROUND get_state | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
echo "Current round state: $ROUND_STATE"
NEW_ROUND_STATE=$ROUND_STATE

# Get current time
NOW=$(date +%s)
echo "Current time: $NOW"

# Get round dates
AUCTION_START=$(starkli call $CURRENT_ROUND get_auction_start_date | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
AUCTION_END=$(starkli call $CURRENT_ROUND get_auction_end_date | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
SETTLEMENT=$(starkli call $CURRENT_ROUND get_option_settlement_date | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')

echo "Round dates:"
echo "Auction start: $AUCTION_START (in $((AUCTION_START - NOW)) seconds)"
echo "Auction end: $AUCTION_END (in $((AUCTION_END - NOW)) seconds)"
echo "Settlement: $SETTLEMENT (in $((SETTLEMENT - NOW)) seconds)"

# Function to format seconds into human readable time
format_seconds() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    echo "${hours} hours ${minutes} minutes ${secs} seconds"
}

# Convert seconds to more readable format for each difference
echo "\nTime until next transitions:"
echo "Time until auction start: $(format_seconds $((AUCTION_START - NOW)))"
echo "Time until auction end: $(format_seconds $((AUCTION_END - NOW)))"
echo "Time until settlement: $(format_seconds $((SETTLEMENT - NOW)))"

TIME_UNTIL_AUCTION_START=$((AUCTION_START - NOW))
TIME_UNTIL_AUCTION_END=$((AUCTION_END - NOW))
TIME_UNTIL_SETTLEMENT=$((SETTLEMENT - NOW))

# Check current state and run appropriate tests
if [ "$ROUND_STATE" -eq 0 ] || [ "$NEW_ROUND_STATE" -eq 0 ]; then
    echo "Round in OPEN state (0), running OPEN state tests..."

    #==============================================
    #test_start_auction_early_should_fail
    #==============================================
    echo "\nTesting early auction start rejection..."
    NOW=$(date +%s)
    echo "Attempting to start auction $((AUCTION_START - NOW)) seconds too early (should fail)"

    if starkli invoke $VAULT_ADDRESS start_auction --account $STARKNET_ACCOUNT --watch 2>/dev/null; then
        echo "[FAILED] Transaction succeeded but should have been rejected!"
        exit 1
    else
        echo "[PASSED] Transaction correctly rejected (auction start time not reached)"
    fi

    #==============================================
    #test_start_auction_on_time_should_succeed
    #==============================================

    echo "\nWaiting for auction_start time to be reached..."
    NOW=$(date +%s)
    sleep $((AUCTION_START - NOW + 1))
    echo "\nTransitioning round from OPEN (0) to AUCTIONING (1)..."
            
    # Call start_auction on the vault and wait for confirmation
    starkli invoke $VAULT_ADDRESS start_auction --account $STARKNET_ACCOUNT --watch

    # Get new state to verify transition
    NEW_ROUND_STATE=$(starkli call $CURRENT_ROUND get_state | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
    echo "New round state: $NEW_ROUND_STATE"

    if [ "$NEW_ROUND_STATE" -eq 1 ]; then
        echo "[PASSED] Successfully transitioned to AUCTIONING state"
    else
        echo "[FAILED] Failed to transition to AUCTIONING state"
        exit 1
    fi
fi

if [ "$ROUND_STATE" -eq 1 ] || [ "$NEW_ROUND_STATE" -eq 1 ]; then
    echo "Round in AUCTIONING state (1), running AUCTIONING state tests..."
    
    #==============================================
    #test_end_auction_early_should_fail
    #==============================================
    echo "\nTesting ending auction early..."
    NOW=$(date +%s)
    echo "Attempting to end auction $((AUCTION_END - NOW)) seconds too early (should fail)"

    if starkli invoke $VAULT_ADDRESS end_auction --account $STARKNET_ACCOUNT --watch 2>/dev/null; then
        echo "[FAILED] Transaction succeeded but should have been rejected!"
        exit 1
    else
        echo "[PASSED] Transaction correctly rejected (auction end time not reached)"
    fi

    #==============================================
    #test_end_auction_on_time_should_succeed
    #==============================================
    echo "\nWaiting for auction_end time to be reached..."
    NOW=$(date +%s)
    sleep $((AUCTION_END - NOW + 1))
    echo "\nTransitioning round from AUCTIONING (1) to RUNNING (2)..."
            
    starkli invoke $VAULT_ADDRESS end_auction --account $STARKNET_ACCOUNT --watch

    NEW_ROUND_STATE=$(starkli call $CURRENT_ROUND get_state | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
    echo "New round state: $NEW_ROUND_STATE"

    if [ "$NEW_ROUND_STATE" -eq 2 ]; then
        echo "[PASSED] Successfully transitioned to RUNNING state"
    else
        echo "[FAILED] Failed to transition to RUNNING state"
        exit 1
    fi
fi

if [ "$ROUND_STATE" -eq 2 ] || [ "$NEW_ROUND_STATE" -eq 2 ]; then
    echo "Round in RUNNING state (2), running RUNNING state tests..."
    
    #==============================================
    #test_settle_round_early_should_fail
    #==============================================
    NOW=$(date +%s)
    echo "\nTesting early settlement rejection..."
    echo "Attempting to settle round $((SETTLEMENT - NOW)) seconds too early (should fail)"

    if starkli invoke $VAULT_ADDRESS settle_round --account $STARKNET_ACCOUNT --watch 2>/dev/null; then
        echo "[FAILED] Transaction succeeded but should have been rejected!"
        exit 1
    else
        echo "[PASSED] Transaction correctly rejected (settlement time not reached)"
    fi

    #==============================================
    #test_settle_round_without_pricing_data_should_fail
    #==============================================
    echo "\nWaiting for settlement time to be reached..."
    NOW=$(date +%s)
    sleep $((SETTLEMENT - NOW + 1))
    echo "\nTesting settlement without pricing data rejection..."

    if starkli invoke $VAULT_ADDRESS settle_round --account $STARKNET_ACCOUNT --watch 2>/dev/null; then
        echo "[FAILED] Transaction succeeded but should have been rejected!"
        exit 1
    else
        echo "[PASSED] Transaction correctly rejected (pricing data not set)"
    fi

    #==============================================
    #test_settle_round_should_succeed
    #==============================================
    echo "\nSetting up settlement with Fossil..."

    # Get request to settle round
    REQUEST_DATA=$(starkli call $VAULT_ADDRESS get_request_to_settle_round)
    echo "Settlement request data: $REQUEST_DATA"

    # Format request for Fossil API
    # The request data contains [id, vault_address, timestamp, program_id]
    VAULT_ADDRESS=$(echo $REQUEST_DATA | jq -r '.[1]')
    TIMESTAMP_HEX=$(echo $REQUEST_DATA | jq -r '.[2]')
    IDENTIFIER=$(echo $REQUEST_DATA | jq -r '.[3]')
    # Convert hex timestamp to decimal (strip 0x and convert)
    TIMESTAMP=$((16#${TIMESTAMP_HEX#0x}))

    echo "Decoded request data:"
    echo "Vault address: $VAULT_ADDRESS"
    echo "Timestamp: $TIMESTAMP"
    echo "Identifier: $IDENTIFIER"

    # Call Fossil pricing data endpoint to initiate the request
    ONE_MONTH_SECONDS=2592000
    ONE_WEEK_SECONDS=604800

    FOSSIL_RESPONSE=$(curl -X POST "http://localhost:3000/pricing_data" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $FOSSIL_API_KEY" \
        -d "{
            \"identifiers\":[\"$IDENTIFIER\"],
            \"params\": {
                \"twap\": [$(($TIMESTAMP - $ONE_WEEK_SECONDS)), $TIMESTAMP], 
                \"volatility\": [$(($TIMESTAMP - $ONE_WEEK_SECONDS)), $TIMESTAMP],
                \"reserve_price\": [$(($TIMESTAMP - $ONE_MONTH_SECONDS)), $TIMESTAMP]
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

    echo "\nTransitioning round from RUNNING (2) to SETTLED (3)..."

    # Call settle_round on the vault and watch for confirmation
    OUTPUT=$(starkli invoke $VAULT_ADDRESS settle_round --account $STARKNET_ACCOUNT --watch)
    EXIT_CODE=$?

    if [ $EXIT_CODE -ne 0 ]; then
        echo "[FAILED] Transaction failed but should have succeeded!"
        echo "Output: $OUTPUT"
        exit 1
    fi

    # Extract transaction hash from output if successful
    TX_HASH=$(echo "$OUTPUT" | grep -o '0x[0-9a-f]*' || echo "No transaction hash found")
    echo "Transaction hash: $TX_HASH"

    # Get new state to verify transition
    NEW_ROUND_STATE=$(starkli call $CURRENT_ROUND get_state | grep -o '0x[0-9a-f]*' | head -1 | xargs printf '%d')
    echo "New round state: $NEW_ROUND_STATE"

    if [ "$NEW_ROUND_STATE" -eq 3 ]; then
        echo "[PASSED] Successfully transitioned to SETTLED state"
    else
        echo "[FAILED] Failed to transition to SETTLED state"
        exit 1
    fi
fi

if [ "$ROUND_STATE" -eq 3 ] || [ "$NEW_ROUND_STATE" -eq 3 ]; then
    echo "Round in SETTLED state (3), no transitions possible"
    echo "This round is settled. No further state transitions are possible."
    exit 0
fi


