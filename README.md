# tp0

## Common commands

- Start API app: `make app`
- Run unit tests: `make unit`
- Run e2e tests: `make e2e`
- Stop normal stack: `make down`
- Stop e2e stack: `make down-e2e`
- Remove containers and volumes: `make clean`

The app is exposed on `http://localhost:8080`.

## Local development guide

This project supports a local-only Stack workflow for development tooling
(Polysemy plugin and Haddock generation) without affecting Docker builds.

These tools are not needed to build the project with Docker and run tests, but they are useful to have while developing and would only bloat and complicate a docker build.

### build tools

The main tool needed is [ghcup](https://www.haskell.org/ghcup/). If you also develop on VSCode, then install the official [haskell extension](https://marketplace.visualstudio.com/items?itemName=haskell.haskell) and if needed, configure the path to the ghcup binary. That should be enough as the extension can figure out which tools and version of the tools need to be downloaded via ghcup (it will ask you for permission).  
If that doesn't work, then at the moment of writing, this project is using:
- Stack 3.7.1
- Cabal 3.14.2.0
- GHC 9.10.3
- HLS 2.13.0

and you can download them manually via ghcup by running in your shell `ghcup tui`

### Local commands

- Local build with Polysemy plugin: `make local-build`
- Build project docs only (lightweight): `make local-docs-project`
- Build docs including dependencies (heavy): `make local-docs`

`make local-build` and docs targets first run `local-bootstrap`, which ensures
`polysemy-plugin` is installed in the local snapshot.
