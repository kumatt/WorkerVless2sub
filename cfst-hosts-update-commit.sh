#!/usr/bin/env bash
set -euo pipefail

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${_SCRIPT_DIR}"

_USAGE() {
	echo "Usage: $(basename "$0") [commit message]"
	echo "Runs cfst_hosts.sh workflow, validates outputs, commits, and pushes."
}

_CHECK_REPO() {
	if [[ ! -f "cfst_hosts.sh" ]]; then
		echo "cfst_hosts.sh not found. Run this script from the repo root."
		exit 1
	fi
	if [[ ! -x "CloudflareST" ]]; then
		echo "CloudflareST not found or not executable in repo root."
		exit 1
	fi
	if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
		echo "Not a git repository."
		exit 1
	fi
	local git_root
	git_root="$(git rev-parse --show-toplevel)"
	if [[ "${git_root}" != "${PWD}" ]]; then
		echo "Repo root is ${git_root}; run this script from there."
		exit 1
	fi
}

_RUN_UPDATE() {
	if [[ -x "/usr/local/sbin/cfst-hosts-update" ]]; then
		echo "Running /usr/local/sbin/cfst-hosts-update..."
		if [[ "${EUID}" -ne 0 ]]; then
			if sudo /usr/local/sbin/cfst-hosts-update; then
				return 0
			fi
			echo "sudo failed; retrying without sudo."
			/usr/local/sbin/cfst-hosts-update
			return 0
		fi
		/usr/local/sbin/cfst-hosts-update
		return 0
	fi

	echo "Running cfst_hosts.sh..."
	if [[ "${EUID}" -ne 0 ]]; then
		if command -v sudo >/dev/null 2>&1; then
			if sudo bash cfst_hosts.sh; then
				return 0
			fi
			echo "sudo failed; running without sudo (hosts update may be skipped)."
			bash cfst_hosts.sh
			return 0
		fi
		echo "sudo not found; running without sudo (hosts update may be skipped)."
		bash cfst_hosts.sh
		return 0
	fi
	bash cfst_hosts.sh
}

_VALIDATE_OUTPUT() {
	if [[ ! -f "result_hosts.txt" ]]; then
		echo "result_hosts.txt not found; aborting."
		exit 1
	fi
	local line_count
	line_count="$(wc -l < result_hosts.txt)"
	line_count="${line_count//[[:space:]]/}"
	if [[ "${line_count}" -lt 2 ]]; then
		echo "result_hosts.txt has no IP rows; aborting."
		exit 1
	fi
	local best_ip
	best_ip="$(awk -F, 'NR==2 {print $1}' result_hosts.txt | tr -d '\r')"
	if [[ -z "${best_ip}" ]]; then
		echo "result_hosts.txt has empty IP column; aborting."
		exit 1
	fi
	if [[ ! -f "nowip_hosts.txt" ]]; then
		echo "nowip_hosts.txt not found; aborting."
		exit 1
	fi
	local now_ip
	now_ip="$(awk 'NR==1 {print $1}' nowip_hosts.txt | tr -d '\r')"
	if [[ -z "${now_ip}" ]]; then
		echo "nowip_hosts.txt is empty; aborting."
		exit 1
	fi
	if [[ "${best_ip}" != "${now_ip}" ]]; then
		echo "nowip_hosts.txt does not match best IP."
		echo "Best IP: ${best_ip}"
		echo "Now IP: ${now_ip}"
		exit 1
	fi
}

_CHECK_GIT_STATUS() {
	local status_lines
	status_lines="$(git status --porcelain)"
	if [[ -z "${status_lines}" ]]; then
		echo "No git changes to commit."
		exit 0
	fi
	local unexpected
	unexpected="$(printf '%s\n' "${status_lines}" | awk '{print $2}' | grep -v -E '^(result_hosts.txt|nowip_hosts.txt)$' || true)"
	if [[ -n "${unexpected}" ]]; then
		echo "Unexpected changed files detected; aborting."
		printf '%s\n' "${unexpected}"
		exit 1
	fi
}

_COMMIT_AND_PUSH() {
	local commit_msg="${1}"
	git status -sb
	git add result_hosts.txt nowip_hosts.txt
	if git diff --cached --quiet; then
		echo "No staged changes to commit."
		exit 0
	fi
	git commit -m "${commit_msg}"
	git push
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	_USAGE
	exit 0
fi

commit_msg="Update CFST hosts"
if [[ "$#" -gt 0 ]]; then
	commit_msg="$*"
fi

_CHECK_REPO
_RUN_UPDATE
_VALIDATE_OUTPUT
_CHECK_GIT_STATUS
_COMMIT_AND_PUSH "${commit_msg}"
