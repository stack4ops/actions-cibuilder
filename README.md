[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-composite-2088FF?logo=github-actions)](action.yml)
[![cibuilder](https://img.shields.io/badge/cibuilder-rootless-blue?logo=docker)](https://github.com/stack4ops/cibuilder)

# actions-cibuilder

A composite GitHub Action that runs a [cibuilder](https://github.com/stack4ops/cibuilder) container as a standalone Docker container in a GitHub Actions job. Used to execute any [cibuild](https://github.com/stack4ops/cibuild) run command — `check`, `build`, `test`, `release`, or `all` — against the checked-out repository.

> For the test run with Docker-in-Docker see [actions-cibuilder-dind](https://github.com/stack4ops/actions-cibuilder-dind).

---

## Usage

```yaml
- uses: actions/checkout@v5
- uses: stack4ops/actions-cibuilder@v1
  with:
    run_cmd: build
```

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `run_cmd` | ✓ | — | cibuild run command: `check`, `build`, `test`, `release`, or `all` |
| `image` | | `ghcr.io/stack4ops/cibuilder:rootless` | cibuilder image to use |
| `bin_url` | | `""` | Override the cibuild lib download URL (dynamic lib loading) |
| `bin_ref` | | `""` | Override the cibuild lib branch or tag (dynamic lib loading) |

### Environment variables and secrets

The action forwards all variables matching the following prefixes into the container automatically — no explicit `env:` mapping needed in the workflow step:

- `GITHUB_*` — GitHub Actions context (repository, ref, SHA, actor, etc.)
- `ACTIONS_*` — Actions runtime variables (used for OIDC token, cache, etc.)
- `CIBUILD_*` — cibuild configuration and secrets
- `CIBUILDER_*` — cibuilder runtime settings

Pass secrets by setting them as environment variables at the job or workflow level:

```yaml
env:
  CIBUILD_RELEASE_COSIGN_PRIVATE_KEY: ${{ secrets.CIBUILD_RELEASE_COSIGN_PRIVATE_KEY }}
  CIBUILD_TARGET_REGISTRY_PASS: ${{ secrets.CIBUILD_TARGET_REGISTRY_PASS }}
```

### Output files

Release artifacts (SBOM, provenance, digests, cosign cert) are written to `$RUNNER_TEMP/cibuild-output/` and can be accessed in subsequent steps:

```yaml
- uses: softprops/action-gh-release@v2
  with:
    files: |
      ${{ runner.temp }}/cibuild-output/digests.json
      ${{ runner.temp }}/cibuild-output/sbom-linux-amd64.spdx.json
      ${{ runner.temp }}/cibuild-output/provenance-linux-amd64.slsa.json
      ${{ runner.temp }}/cibuild-output/cert.json
```

---

## Full Pipeline Example

The following example mirrors the cibuilder self-build pipeline: native parallel builds on amd64 and arm64, followed by a combined release job.

```yaml
jobs:
  check:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      actions: write        # required for pipeline cancellation in the check run
    steps:
      - uses: actions/checkout@v5
      - uses: stack4ops/actions-cibuilder@v1
        with:
          run_cmd: check

  build:
    needs: check
    strategy:
      fail-fast: true
      matrix:
        include:
          - runner: ubuntu-latest        # amd64
          - runner: ubuntu-24.04-arm     # arm64
    runs-on: ${{ matrix.runner }}
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5
      - uses: stack4ops/actions-cibuilder@v1
        with:
          run_cmd: build

  test:
    needs: build
    strategy:
      fail-fast: true
      matrix:
        include:
          - runner: ubuntu-latest
          - runner: ubuntu-24.04-arm
    runs-on: ${{ matrix.runner }}
    permissions:
      contents: read
      packages: read
    steps:
      - uses: actions/checkout@v5
      - uses: stack4ops/actions-cibuilder-dind@v1   # DinD variant for test run
        with:
          run_cmd: test

  release:
    needs: test
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write       # required for keyless cosign signing
    steps:
      - uses: actions/checkout@v5
      - uses: stack4ops/actions-cibuilder@v1
        with:
          run_cmd: release
```

---

## How It Works

`run.sh` collects all relevant environment variables into a temporary `github.env` file and passes them to the cibuilder container via `--env-file`. The workspace is mounted at `/workspace` and the output directory at `/cibuild-output`. The container runs `--privileged` to support rootlesskit inside the container (required for the embedded daemonless BuildKit).

```sh
docker run --privileged --rm \
  --env-file github.env \
  -v "$PWD:/workspace" \
  -v "${RUNNER_TEMP}/cibuild-output:/cibuild-output" \
  -w /workspace \
  ghcr.io/stack4ops/cibuilder:rootless
```

The `github.env` file is deleted after the run.