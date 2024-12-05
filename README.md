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
git submodule update --init --recursive --remote
```

Whenever you want to fetch the latest changes from the submodules, run:
```bash
git submodule update --remote --recursive
```

**Note:** Whenever fetching the latest changes from the submodules, the docker images for each component will likely be outdated. To rebuild the images, run `docker compose build` in the root of the repo. If things don't look as expected, you can also run `docker compose build --no-cache` for a clean build.

### 2. Setting up the Argent wallet for local testing

The steps below are needed so you can interact with the UI on the local devnet.

- Install the Argent wallet extension in your browser
- Go to Settings -> Developer Settings -> Manage Networks -> click on the + button
- Add a new network with the following:
  - Name: Juno Devnet
  - RPC URL: http://localhost:6060
  - Chain ID: SN_JUNO_SEQUENCER
- Connect the wallet to the newly created network and create a new account
- Next you will need to copy the wallet's address, salt and constructor arguments and paste them into the .env file. 
    - the salt and constructor arguments can be found in the Argent extension under Settings -> Developer Settings -> Deployment Data
    - once you click on the "Deployment Data" button, you will see a json object similar to the one below -- you need to copy the `addressSalt` and **the second value** in the `constructorCalldata` array.

    ```json
    {
        "classHash":"0x036078334509b514626504edc9fb252328d1a240e4e948bef8d0c08dff45927f",
        "constructorCalldata":["0","37459222005894634870375857944293937532221532474070351093573957772534191899","1"],
        "addressSalt":"0x15337fc442ab75a3589746a426987f9dfb49b3abd8d447dab3550c3ead971b",
        "contractAddress":"0x0768d44b56fd0f6f660a449697c906391b1ae682b30086f4d521c4c414d399d9",
        "version":"1"
    }
    ```

### 3. Fetch the vault contract class hash

The vault contract class hash is needed for the Indexer to identify the address of the vault.
You can generate the class hash using `starkli declare` and then copying the class hash from the output. 

TODO: Write an automated way to fetch the class hash

### 3. Setting up the environment variables

- Create a `.env` file in the root of the repo, using the `.env.example` as a template.
- Paste in the Argent wallet values from the previous step and fill in the rest of the values
- Paste in the vault contract class hash

### 4. Starting the services

To start all the services run:
```bash
docker compose up
```

To track the logs of a service, open a new terminal and run:
```bash
docker compose logs -f <service_name>
```

**Note:** The devnet's state is persistent between restarts. If you want to reset the state, you need to run `docker compose down -v` to remove the volumes, then run `docker compose up` again.

## Recommended workflow

Let's say we want to work on one of the components. We can add changes to the submodule directly and the push them to the remote repo.

1. cd into submodule directory
2. create a new branch: `git checkout -b my-branch`
3. make changes and commit them: `git commit -am 'my changes'`
4. push to remote: `git push origin my-branch`
5. open a PR in the submodule's remote repo




