# ServiceNow

Two ways to connect change management to these tools. Both use the same contract: **`azvm-gate check` exits 0 to allow, 10 to deny, 2 for a usage error**, with a `--json` form for machines.

> **Status: NOT tested against a live ServiceNow instance.** The provider is exercised only against a fixture (`tests/fixtures/snow-ok.json`) built from the documented Table API response shape (`sysparm_display_value=all`). Verify every field and state value below in your own instance first.

## Pattern A: the operator pulls (built in)

The person (or agent) runs the tool with `GATE_PROVIDER=servicenow`. The gate reads the change request over the Table API, read-only, and decides.

```bash
export GATE_PROVIDER=servicenow
export SNOW_INSTANCE=yourcompany.service-now.com   # must match *.service-now.com unless you set SNOW_HOST_REGEX
./bin/azvm-resize --vm my-vm --target-size Standard_D4as_v5 --change CHG0030001 --apply
```

What the provider checks on `change_request`:

| Field | Required | Default expectation | Override |
|---|---|---|---|
| `number` | equals `--change` | exact | |
| `state` (value) | in an allowed list | `-1` (Implement in the out-of-box model, as we understand it) | `SNOW_OK_STATES="-1 -2"` |
| `approval` (value) | `approved` | on | `SNOW_REQUIRE_APPROVED=0` |
| `cmdb_ci` (display value) | equals the VM name | on | `SNOW_SKIP_CI_CHECK=1` |
| `start_date`, `end_date` (value, UTC) | now is inside | always | |

Verify your instance's state numbers: look at the choice list for `change_request.state`. The out-of-box normal-change states we expect are New, Assess, Authorize, Scheduled, Implement, Review, Closed, Canceled. Do not trust our numbers over your instance.

### Credentials

Use a dedicated integration user with **read-only** access to `change_request`, or an OAuth token, stored in the macOS Keychain. The `-w` flag with no value makes `security` prompt, so the secret never appears in your shell history or process list:

```bash
security add-generic-password -s mac4azure-snow -a token -w                 # a bearer token, or
security add-generic-password -s mac4azure-snow -a "$SNOW_USER" -w          # a password
```

The tool refuses to send credentials to any host that does not match the allowed pattern, and passes them to `curl` on stdin.

## Pattern B: the workflow pushes

Let the change workflow decide when, and the Mac (or a runner) do the work. A Flow Designer flow, a ServiceNow Orchestration step, an Azure Automation runbook, a Logic App or a pipeline calls:

```bash
./bin/azvm-gate check --action resize --vm "$VM" --change "$CHG" --json
```

and only proceeds on exit 0. The same JSON contract works from anywhere that can run a shell. The gate re-checks the window at the moment of the call, so a change that slipped out of its window is denied even if the workflow started late.

Not included in v1: writing work notes or closing the change from the tool. The audit log has what you need to do that from the workflow.

## Maintenance windows

See [MAINTENANCE-WINDOWS.md](MAINTENANCE-WINDOWS.md).
