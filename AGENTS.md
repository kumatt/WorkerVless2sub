# Repository Guidelines

This repo wraps CloudflareST with a small Bash workflow to pick the fastest IP and update `/etc/hosts`.

## Project Structure & Module Organization
- `cfst_hosts.sh` is the main workflow script; it runs CloudflareST and swaps the IP in `/etc/hosts`.
- `CloudflareST` is the prebuilt binary invoked by the script.
- `ip.txt` and `ipv6.txt` contain Cloudflare CIDR ranges (one per line) for direct CloudflareST runs.
- `nowip_hosts.txt` stores the last IP used in hosts; `result_hosts.txt` is the latest CloudflareST output.

## Build, Test, and Development Commands
- `./CloudflareST -o result_hosts.txt` runs a speed test and writes the CSV output file.
- `bash cfst_hosts.sh` runs the full update flow; it prompts for the current IP on first run.
- `sudo bash cfst_hosts.sh` is typically required because the script writes to `/etc/hosts` and `/etc/hosts_backup`.

## Coding Style & Naming Conventions
- Bash only; keep the existing `#!/usr/bin/env bash` header.
- Follow current formatting (tabs for indentation) and function naming like `_CHECK` / `_UPDATE`.
- Data files use snake_case and clear suffixes (e.g., `*_hosts.txt`, `ip.txt`, `ipv6.txt`).
- Text lists are newline-separated CIDR blocks.

## Testing Guidelines
No automated tests. Validate manually:
- Confirm `result_hosts.txt` contains at least one IP after running CloudflareST.
- Run the script and verify `/etc/hosts_backup` is created and `/etc/hosts` swaps the IP.

## Commit & Pull Request Guidelines
- Git history uses simple, imperative messages (e.g., "Add ipv6 ranges"). Keep that style.
- PRs should include a short summary, commands run, and note any changes to `CloudflareST` or host-update behavior.

## Security & Configuration Tips
- The script replaces the previous IP stored in `nowip_hosts.txt`; update it if you modify hosts manually.
- `sed -i ''` is macOS-specific; adjust if running on Linux.
