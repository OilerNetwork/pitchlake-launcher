# pitchlake-launcher
The only repo you need to spin up every pitchlake component

## Usage

In this repo all the Pitchlake components are referenced as git submodules.
After cloning the repo, you need to initialize the submodules by running:
```bash
git submodule update --init --recursive
```

To start all the services run:
```bash
docker-compose up
```

