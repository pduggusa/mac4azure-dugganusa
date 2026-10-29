# Examples

- `change.example.json`: a change record for the `file` gate provider. Copy it, edit it, point `GATE_FILE` at it, set `GATE_PROVIDER=file`.
- `servicenow-response.example.json`: the shape of a `change_request` Table API response (`sysparm_display_value=all`) that the `servicenow` provider parses. Use it with `SNOW_FIXTURE` to test without an instance.

Try a full gate decision offline:

```bash
GATE_PROVIDER=file GATE_FILE=examples/change.example.json ./bin/azvm-gate check --action resize --vm example-vm --change CHG0030001
```

(It will say DENY unless the current time is inside the example window. That is the point.)
