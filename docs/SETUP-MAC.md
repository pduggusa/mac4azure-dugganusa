# Setup on a Mac

Everything here is free. Nothing in the tools requires a paid Azure feature.

## Prerequisites

| Tool | Why | Install | Source |
|---|---|---|---|
| Homebrew | package manager for the rest | see the project site | https://brew.sh |
| Azure CLI (`az`) | every Azure call | `brew install azure-cli` | https://learn.microsoft.com/cli/azure/install-azure-cli-macos |
| `jq` | all JSON handling | `brew install jq` | https://jqlang.github.io/jq/ |
| `curl`, `git`, `ssh`, `awk`, `sed`, `date` | already on macOS | none | |
| bash 3.2 | already on macOS (`/bin/bash`) | none: the tools are written for it | |

Optional, recommended:

| Tool | Why | Note |
|---|---|---|
| `shellcheck` | lint the scripts before you change them | `brew install shellcheck`. **We did not run it** (not installed on the test machine); it is a recommendation, not a claim. |
| `gh` | clone, review and open pull requests | `brew install gh` |
| A password manager or the macOS Keychain | the only place a ServiceNow credential should live | see docs/SERVICENOW.md |

## Sign in

```bash
az login                          # opens a browser; use an Entra ID user with MFA
az account list -o table          # confirm you can see the subscription you expect
export AZVM_SUBSCRIPTION="<id or name>"
```

Sign-in documentation: https://learn.microsoft.com/cli/azure/authenticate-azure-cli

Good habits on a laptop:

- **FileVault on.** `az` keeps its token cache under `~/.azure`. Treat that folder like a credential.
- **One config directory per tenant** so a command can never land in the wrong one: `export AZURE_CONFIG_DIR=~/.azure-contoso` before `az login`.
- **`az logout`** when you are done with a change window.
- **No service principal secrets on the laptop.** If automation needs an identity, give it a managed identity or a federated credential on a runner, not a secret in a file.

## Check it works

```bash
./tests/run-tests.sh              # offline, no Azure needed
./bin/azvm-sizes --location eastus2 Standard_D4as_v5   # read-only, proves login and quota access
```

## Clone

```bash
git clone https://github.com/pduggusa/mac4azure-dugganusa.git
cd mac4azure-dugganusa
```
