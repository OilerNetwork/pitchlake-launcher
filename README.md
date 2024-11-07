# pitchlake-launcher
The only repo you need to spin up every pitchlake component

## Usage

In this repo all the Pitchlake components are referenced as git submodules.

After cloning the repo, you need to initialize the submodules by running:
```bash
git submodule update --init --recursive
```

Whenever you want to fetch the latest changes from the submodules, run:
```bash
git submodule update --remote
```

To start all the services run:
```bash
docker compose up
```

To track the logs of a service, open a new terminal and run:
```bash
docker compose logs -f <service_name>
```

Note: The devnet's state is preserved between restarts. If you want to reset the state, you need to run `docker compose down -v` to remove the volumes.

## Recommended workflow

Let's say we want to work on one of the components. We can add changes to the submodule directly and the push them to the remote repo.

1. cd into submodule directory
2. create a new branch: `git checkout -b my-branch`
3. make changes and commit them: `git commit -am 'my changes'`
4. push to remote: `git push origin my-branch`
5. open a PR in the submodule's remote repo




