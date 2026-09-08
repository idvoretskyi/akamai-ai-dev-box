# Security Policy

## Reporting

Use GitHub's private vulnerability reporting for [idvoretskyi/akamai-ai-dev-box](https://github.com/idvoretskyi/akamai-ai-dev-box/security/advisories/new) when it is enabled. If the private reporting form is unavailable, open a public issue requesting a private contact channel **without vulnerability details, credentials, host addresses, or logs**. Do not publish an exploit while arranging private contact.

Include the affected commit, relevant tool versions, a minimal redacted reproduction, impact, and suggested mitigation in the private report. Never send private keys, API tokens, real OpenTofu state or plans, or unredacted user data. If a credential has been exposed, revoke or rotate it promptly; deleting a Git commit or issue does not revoke access.

## Support Scope

This is an early-stage community project without a security response SLA. Security fixes target the current default branch; no older-release support commitment is made. The baseline has not been certified or established as GPU-tested by static validation.

Report repository provisioning or configuration vulnerabilities here. Report upstream vulnerabilities to the relevant OpenTofu, Linode provider, Ubuntu, NVIDIA, Ollama, or OpenCode security team as appropriate, and notify this project privately when its defaults are affected.

Read [the security model](docs/security.md) before deployment. It explains why loopback Ollama, a provider allowlist, and an OpenTofu `sensitive` variable are not substitutes for isolation, credential hygiene, or encrypted state.
