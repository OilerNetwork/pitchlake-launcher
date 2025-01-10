# Pitch Lake Launcher

This is the main repository for running Pitch Lake on your local computer. This guide will help you set up everything you need.

For more information about Pitchlake, check out the links below
[Pitch Lake Crash Course](https://github.com/OilerNetwork/pitchlake_starknet/blob/main/documentation.md) | [Pitch Lake Whitepaper](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4123018) | [Oiler Network](https://www.oiler.network/)

## What is this?

This repository acts as a central hub that brings together all the different pieces of Pitchlake. It imports all the repositories and sets them up to work together on your computer.

The main components that get set up are:
- The Pitch Lake frontend
- The Fossil api - generates the pricing data and sets it in the smart contracts
- The Juno node (with sequencer and the indexer plugins) - this acts as a local devnet, processing transactions, producing blocks and sending notifications about newly produced blocks. The indexer plugin is used to store the events in a postgres database.
- A postgres database - used to store the Pitch Lake contracts events
- A websocket server - feeds the data from the db into the UI
- Pitch Lake contracts - Cairo contracts that are deployed to the Juno devnet

All of these pieces are automatically configured to work together when you follow this guide.

## Prerequisites

Before starting, please make sure you have the following installed on your computer:
1. [Docker](https://www.docker.com/products/docker-desktop/) - the main tool we'll use to run everything
2. [Git](https://git-scm.com/downloads) - needed to download the code
3. [Argent Wallet](https://www.argent.xyz/) browser extension - the wallet we'll use to interact with Pitch Lake from your browser

## Step-by-Step Setup Guide

### 1. Download the Project

1. Open your terminal (Command Prompt on Windows, Terminal on Mac/L)
2. Run these commands one by one:
   ```bash
   git clone https://github.com/OilerNetwork/pitchlake-launcher
   cd pitchlake-launcher
   git submodule init
   git submodule update --remote
   ```

### 2. Create Your Configuration File

Edit the .env file
Copy `.env.example` to `.env` and fill in the appropriate values.

1. Copy .env.example to .env
   ```bash
   cp .env.example .env
   ```
2. Fill in the values for `FOSSIL_API_KEY` and `FOSSIL_DATABASE_URL`. Reach out to the Fossil / Pitchlake team for these values.
3. Save the file

Notes:
- The following variables set the duration of the round states: `ROUND_TRANSITION_DURATION` (Open State), `AUCTION_DURATION` (Auctioning State), `ROUND_DURATION` (Running State)
- The frontend can be set to use data from different sources. 
  - `UI_DATA_SOURCE=rpc` - DEFAULT, get data from rpc
  - `UI_DATA_SOURCE=ws` - use the data provided by the websocket server
  - `UI_DATA_SOURCE=mock` - use mock data for testing (this is useful to devs who want to test/debug specific scenarios)
- `FOSSIL_USE_MOCK_PRICING_DATA` can set the Fossil API to use mock pricing data. Computing the pricing data takes a lot of time, so this is useful to speed up the development/testing process. By default, this is set to true.

### 3. Declare the Vault Contract

1. Make sure Docker Desktop is running
2. In your terminal, run:
   ```bash
   source .env
   docker compose -f docker-compose.declare-vault.yml up declare-vault
   ```
3. From the output, look for the line containing "Class hash declared:"
4. Copy the hash value that appears after this text
5. Open your `.env` file again
6. Paste the class hash as the value for `VAULT_HASH`. ❗❗❗ Remove all leading 0s from the hash ❗❗❗
  - ❌ Incorrect format: `0x0516...`
  - ✅ Correct format: `0x516...`
7. Save the file

### 4. Start Pitchlake

1. Make sure you're in the pitchlake-launcher folder in your terminal
2. Run these commands:
   ```bash
   source .env
   docker compose up
   ```   
3. Wait for everything to start up - this might take around 10-20 minutes the first time, because the docker images need to be built. You can see the progress in the terminal. The services will start in sequence, because some depend on others. The frontend will be the last one to start.
4. To see if the services are healthy and running, you can check the logs of the individual containers. Run each component's logs, open a new terminal in the root directory of the project and run `docker compose logs -f <component_name>`. If nothing happens when you run one of the commands, it means the service hasn't started yet. Try again after a few seconds.

   ```bash
   docker compose logs -f juno_plugin
   docker compose logs -f contracts_deployment
   docker compose logs -f fossil_api
   docker compose logs -f frontend
   docker compose logs -f websocket
   ```

### 5. Checking if the system works

Integration tests run automatically when you start the system with a clean state. 

To see the test results, check the `integration_tests` container logs:
```bash
docker compose logs -f integration_tests
```

To see what the tests are doing check `round-transitions-test.sh`.

### 6. How to see if individual components are running

By checking the logs of the individual services, you can tell if they are running and ready to use. 

If not sure, you can also check the individual service like this:
- The Pitch Lake frontend will be available in your browser at: http://localhost:3003.  
- The Fossil API will be available at: http://localhost:3000. 
   - To check if the API is healthy, open a terminal and run:
     ```bash
     curl -s http://localhost:3000/health
     ```
   - If the API is running, you'll get a response indicating it's healthy
- The Juno node will be available at: http://localhost:6060.
   - To check if the node is healthy, open a terminal and run:
     ```bash
     curl -s -X POST \
          -H "Content-Type: application/json" \
          --data '{
              "jsonrpc": "2.0",
              "method": "juno_version",
              "id": 1
          }' \
          http://localhost:6060
     ```
   - If the node is running, you'll get a response with the Juno version
- The Postgres database will be available at: localhost:5433.
   - You can connect to the database using this connection URL:
     ```
     postgres://pitchlake_user:pitchlake_password@localhost:5433/pitchlake_db
     ```
   - Or these individual credentials:
     - Host: localhost
     - Port: 5433
     - Database: pitchlake_db
     - Username: pitchlake_user
     - Password: pitchlake_password
- Contracts deployments
  - can only be checked looking at the logs of the contracts_deployment container
  - `docker compose logs -f contracts_deployment`

- Websocket server
  - can only be checked looking at the logs of the db_server container
  - `docker compose logs -f websocket`

### 6. Using Pitchlake

Now that everything is set up and verified, you can start using Pitch Lake through the web interface.

1. Access the Pitch Lake UI:
   - Open your browser and go to http://localhost:3003
   - You should see the Pitch Lake interface

2. Set up your wallet:
   1. Install the Argent wallet extension in your browser if you haven't already
   2. Open the Argent wallet
   3. Click on Settings (gear icon)
   4. Go to Advanced Settings
   5. Click on Manage Networks
   6. Click on Devnet (do not create a new network - importing accounts only works on the default devnet)
   7. Update the following fields with exactly these values:
      - Chain ID: `SN_JUNO_SEQUENCER`
      - RPC URL: `http://localhost:6060`
      - Account classhash: `0x1a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003`
      - Fee Token: `0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7`
   8. From the main wallet screen:
      - Click on your account name at the top
      - Select the network dropdown
      - Switch to "Devnet"
      - Look for the "Add account" button at the bottom
      - Click "Add account" to proceed with importing
   9. Select the "Import from private key" option and add the following account into the wallet
      - Address: 0x406a8f52e741619b17410fc90774e4b36f968e1a71ae06baacfe1f55d987923
      - Private key: 0x3a4791edf67fa0b32b812e41bc8bc4e9b79915412b1331f7669cbe23e97e15a

3. Interact with Pitchlake:
   - Connect your wallet by clicking the "Connect Wallet" button
   - You should now be able to see your account balance and interact with the platform
   - A round should be active and ready for participation


## Tips and Tricks

### Persistent State
The devnet's state (including accounts, transactions, and contract deployments) is persistent. This means that if you stop and restart the system, you'll still have the same state as when you left it.

If you want to start fresh with a clean state:
1. Stop all services (Ctrl+C in the terminal)
2. Run `docker compose down -v` to remove all stored data
3. Run `docker compose up` to start with a fresh state

Note: Reseting the state is likely to cause issues with the nonce of your wallet. Argent maintains the wallet nonce in the cache, while Juno will expect the nonce to be 0. To reset the nonce, check the troubleshooting section.

### Pitch Lake components have been updated
When you fetch the latest changes from the submodules (using `git submodule update --remote`), you'll need to rebuild the docker images for the components that have been updated:

1. Stop all services if they're running (Ctrl+C in the terminal)
2. Run `docker compose build` to rebuild all the images
3. Alternatively, you can rebuild a specific component by running `docker compose build <component_name>`:
   - `docker compose build contracts_deployment`
   - `docker compose build fossil_api`
   - `docker compose build frontend`
   - `docker compose build db_server`
   - `docker compose build juno_plugin`
3. If you experience any issues, try using the `--no-cache` flag in any of the commands above:
   ```
   docker compose build --no-cache
   ```
4. Start the services again with `docker compose up`

## Troubleshooting

### If transactions do not update the UI

If you experience issues with transactions having no effect, it's possible that the wallet's nonce needs to be reset. To confirm this, you can check the Juno node's while sending a tx. An error DEBUG log indicating a nonce mismatch should appear (`Invalid transaction nonce of contract at address`)

To fix this, you can reset the Argent wallet nonce and start the system with a clean state:
1. Stop the docker containers by pressing Ctrl+C in the terminal
2. Run `docker compose down -v` to clean up everything
3. Run `docker compose up` to start fresh
4. Right-click on the Argent extension window and select "Inspect"
5. Click on the "Console" tab
6. Type `chrome.storage.session.clear()` and press Enter
7. Unlock your wallet and try again

### If everything was working well and it not working as expected anymore:
1. Stop everything by pressing Ctrl+C in the terminal
2. Run `docker compose down -v` to clean up everything
3. Run `docker compose up` to start fresh


## Need Help?

If you're having trouble with any of these steps, please reach out to the Pitch Lake team for assistance.





