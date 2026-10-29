# Security

This library can change production infrastructure, so safety reports matter.

**Report a vulnerability privately** through GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability"). Please do not open a public issue for something exploitable.

Things we especially want to hear about: a way to make `--apply` run without a passing change gate; a way for a credential to reach a command line, a log or the audit file; a way for the ServiceNow provider to send credentials to a host other than the allowed pattern; a hook mechanism that runs something other than a file in `hooks/`.

We do not store secrets in this repository and the tests need none.
