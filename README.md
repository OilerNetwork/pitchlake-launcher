# pitchlake-launcher
Dockerized dev environment and the only repo you need to contribute to Pitchlake.

## How it works

In this repo all the Pitchlake components are referenced as git submodules. A docker compose file is used to spin up 

- the Juno node with its sequencer (devnet) and plugin which is used to index events
- the Fossil offchain processor
- the UI
- the websocket server feeding data to the UI from the indexer db

On top of that, the docker compose file will deploy the Pitchlake contracts to the devnet.

## Usage

### 1. Initialize submodules

After cloning the repo, you need to initialize the submodules by running:
```bash
git submodule init
```

To fetch the latest changes from the submodules, run:
```bash
git submodule update --remote
```

### 2. Setting up the Argent wallet for local testing

The steps below are needed so you can interact with the UI on the local devnet.

- Install the Argent wallet extension in your browser
- Go to Settings -> Advanced Settings -> Manage Networks -> Devnet
- Update the devnet config to the following:
  - RPC URL: http://localhost:6060
  - Chain ID: SN_JUNO_SEQUENCER
  - Account classhash: 0x1a736d6ed154502257f02b1ccdf4d9d1089f80811cd6acad48e6b6a9d1f2003
  - Fee Token: 0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7
- [the next step does not work since it is not possible to import the account without running the network]
- Import the following account into the Argent wallet:
  - Address: 0x406a8f52e741619b17410fc90774e4b36f968e1a71ae06baacfe1f55d987923
  - Private key: 0x3a4791edf67fa0b32b812e41bc8bc4e9b79915412b1331f7669cbe23e97e15a

### 3. Fetch the vault contract class hash

[The following will not work since .env is only created in the next step]
The vault contract class hash is needed for the Indexer to identify the address of the vault.
To generate the class hash, run:
1. `source .env`
2. `docker compose -f docker-compose.declare-vault.yml up declare-vault`

Then copy the class hash from the output and paste it into the .env file.

### 3. Setting up the environment variables

[Incorrect step numbering, also it is not clear what values and where to insert from Argent]
- Create a `.env` file in the root of the repo, using the `.env.example` as a template.
- Paste in the Argent wallet values from the previous step and fill in the rest of the values
- Paste in the vault contract class hash

### 4. Starting the services

To start all the services run:
1. `source .env`
2. `docker compose up`

To track the logs of a service, open a new terminal and run:
[What is the service name here?]
```bash
docker compose logs -f <service_name>
```
[Where is any info in readme on launching the UI / addresses of relative services / simple RPC tests and commands to verify everything?]

**Note:** Whenever fetching the latest changes from the submodules, the docker images for each component will likely be outdated. To rebuild the images, run `docker compose build` in the root of the repo. If things don't look as expected, you can also run `docker compose build --no-cache` for a clean build.

**Note:** The devnet's state is persistent between restarts. If you want to reset the state, you need to run `docker compose down -v` to remove the volumes, then run `docker compose up` again.

## Runninng the integration tests

[Which contracts deployed? How to verify the contracts are deployed?]
To run the integration tests, you need to have the contracts deployed. Once the contracts are deployed, you need to fill in the FOSSILCLIENT_ADDRESS and VAULT_ADDRESS values in the .env file and run:

[ERROR: FOSSIL_API_KEY not set in .env file]

```bash
sh round-transitions-test.sh
```

## Recommended workflow

Let's say we want to work on one of the components. We can add changes to the submodule directly and the push them to the remote repo.

1. cd into submodule directory
2. create a new branch: `git checkout -b my-branch`
3. make changes and commit them
4. push to remote: `git push origin my-branch`
5. open a PR in the submodule's remote repo

## Common issues

1. ### Transactions fail unexpectedly

This is usually an issue around the Argent wallet storing the account's nonce in the browser's local storage. On startup, Juno deploys a new account with nonce 0, while Argent might still have the old nonce from a previous session. In these cases, the transaction will fail with a nonce error. (can be seen as a DEBUG log in the Juno logs)

To fix this, you need to:
1. Lock your wallet
2. Right click inspect
3. In console tab write `chrome.storage.session.clear()`  and enter
4. Unlock your wallet



