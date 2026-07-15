# Public repository safety policy

This is the public documentation and binary-release repository for StabiLink Desktop. It is deliberately isolated from the private source repository.

## Mandatory rules for every AI agent and automation

- Application source code is not allowed in this repository or its Git history.
- Never read from or copy a directory named `StabiLink.Core`, `StabiLink.Desktop`, `StabiLink.CLI`, `VPN`, `infra`, `Backups`, or the private repository `E:\STABILINK(Qoder)` into this repository.
- Never add `.cs`, `.xaml`, project files, build scripts, PDB files, configs, logs, databases, keys, tokens, source archives, patches, or Git bundles.
- Never use `git add .`, `git add -A`, `git push --mirror`, `git push --all`, or `--no-verify`.
- Only add exact paths listed in `.safety/allowed-files.txt`.
- Run `.safety/verify-public-repo.ps1 -Mode Full` before every commit and push.
- The only permitted remote is `sany86russ/StabiLink-Desktop`.
- A production binary may be uploaded only as a GitHub Release asset after explicit owner approval. Never commit a binary or archive to Git.
- Do not create or change a GitHub remote, publish a Release, or make the repository public without explicit confirmation from the owner in the current conversation.

If a requested file is not in the allowlist, stop and ask the owner. Do not expand the allowlist automatically.

