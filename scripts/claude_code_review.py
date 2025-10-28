#!/usr/bin/env python3
import os
import sys
import json
import re
import fnmatch
import subprocess
from typing import List, Tuple

import requests

try:
    import anthropic
except Exception as e:
    print(f"[claude-review] anthropic package not available: {e}", file=sys.stderr)
    # Exit 0 to avoid failing CI if deps missing
    sys.exit(0)

MARKER = "<!-- CLAUDE_REVIEW:do-not-edit -->"

# Reasonable safe default; we further chunk diffs by file boundaries
MAX_CHARS_PER_CHUNK = int(os.environ.get("MAX_CHARS_PER_CHUNK", "60000"))

DEFAULT_INCLUDE_GLOBS = [
    "**/*.tf",
    "**/*.tfvars",
    "**/*.yaml",
    "**/*.yml",
    "**/values*.yaml",
    "**/*.sh",
    "**/Dockerfile",
    "**/Makefile",
    "app_deploy/**",
    "infra_deploy/**",
    "modules/**",
]

def get_owner_repo_from_env():
    repo_full = os.environ.get("GITHUB_REPOSITORY", "")
    if "/" in repo_full:
        owner, repo = repo_full.split("/", 1)
        return owner, repo
    return None, None

def gh_session():
    token = os.environ.get("GITHUB_TOKEN")
    s = requests.Session()
    if token:
        s.headers.update({"Authorization": f"Bearer {token}"})
    s.headers.update({
        "Accept": "application/vnd.github+json",
        "User-Agent": "claude-code-review-bot",
    })
    return s

def fetch_pr(owner: str, repo: str, pr_number: str):
    s = gh_session()
    url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}"
    r = s.get(url, timeout=30)
    r.raise_for_status()
    return r.json()

def latest_open_pr(owner: str, repo: str):
    s = gh_session()
    url = f"https://api.github.com/repos/{owner}/{repo}/pulls?state=open&sort=updated&direction=desc&per_page=1"
    r = s.get(url, timeout=30)
    r.raise_for_status()
    arr = r.json()
    return arr[0] if isinstance(arr, list) and arr else None

def log(msg: str) -> None:
    print(f"[claude-review] {msg}", flush=True)

def run(cmd: str) -> str:
    return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT).strip()

def path_matches(path: str, patterns: List[str]) -> bool:
    for pat in patterns:
        if fnmatch.fnmatch(path, pat):
            return True
        # Also try without ** by converting to simple match for cases like "app_deploy/**"
        if pat.endswith("/**") and path.startswith(pat[:-3]):
            return True
    return False

def load_event() -> dict:
    event_path = os.environ.get("GITHUB_EVENT_PATH")
    if not event_path or not os.path.exists(event_path):
        return {}
    with open(event_path, "r", encoding="utf-8") as f:
        return json.load(f)

def get_pr_context(event: dict) -> Tuple[str, str, str, int, List[str]]:
    """
    Returns (owner, repo, base_sha, head_sha, pr_number, labels)
    """
    repo_owner = event.get("repository", {}).get("owner", {}).get("login")
    repo_name = event.get("repository", {}).get("name")
    pr = event.get("pull_request")
    if not pr:
        return repo_owner, repo_name, None, None, None, []
    base_sha = pr["base"]["sha"]
    head_sha = pr["head"]["sha"]
    pr_number = pr.get("number") or event.get("number")
    labels = [lbl.get("name") for lbl in pr.get("labels", []) if lbl.get("name")]
    return repo_owner, repo_name, base_sha, head_sha, pr_number, labels

def get_changed_files(base: str, head: str) -> List[str]:
    out = run(f"git diff --name-only {base}..{head}")
    files = [line.strip() for line in out.splitlines() if line.strip()]
    return files

def build_filtered_diff(base: str, head: str, include_globs: List[str]) -> Tuple[str, List[str]]:
    changed = get_changed_files(base, head)
    included = [f for f in changed if path_matches(f, include_globs)]
    if not included:
        return "", []
    # Construct unified diff only for included files
    # Split into batches to avoid shell arg length limits if too many files
    diff_chunks = []
    batch = []
    total_len = 0
    # Conservative batching by number of files
    for f in included:
        batch.append(f)
        if len(batch) >= 100:
            cmd = "git diff --unified=3 {}..{} -- {}".format(base, head, " ".join(map(shell_quote, batch)))
            diff_chunks.append(run(cmd))
            batch = []
    if batch:
        cmd = "git diff --unified=3 {}..{} -- {}".format(base, head, " ".join(map(shell_quote, batch)))
        diff_chunks.append(run(cmd))
    diff_text = "\n".join(d for d in diff_chunks if d)
    return diff_text, included

def shell_quote(s: str) -> str:
    # Minimal quoting for safe shell passing
    return "'" + s.replace("'", "'\"'\"'") + "'"

def split_diff_by_file(diff_text: str, max_chars: int) -> List[str]:
    """
    Splits a unified diff into chunks at file boundaries (lines starting with 'diff --git').
    """
    if not diff_text:
        return []
    lines = diff_text.splitlines(keepends=True)
    file_segs = []
    current = []
    for line in lines:
        if line.startswith("diff --git "):
            if current:
                file_segs.append("".join(current))
                current = []
        current.append(line)
    if current:
        file_segs.append("".join(current))

    chunks = []
    buf = ""
    for seg in file_segs:
        if len(buf) + len(seg) > max_chars:
            if buf:
                chunks.append(buf)
                buf = ""
            # If a single seg is bigger than max, still push it alone
            if len(seg) > max_chars:
                chunks.append(seg)
            else:
                buf = seg
        else:
            buf += seg
    if buf:
        chunks.append(buf)
    return chunks

def read_prompt_file() -> str:
    prompt_path = os.path.join(".github", "claude", "prompt.md")
    if os.path.exists(prompt_path):
        try:
            with open(prompt_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            log(f"Failed to read prompt file: {e}")
    # Fallback minimal prompt
    return (
        "You are an expert DevOps/SRE reviewer for Terraform, EKS, IAM/IRSA, Kubernetes, Helm, and Ansible. "
        "Review the provided unified diff for correctness, security, idempotency, cleanup, DRY, and cost. "
        "Output concise Markdown with sections: Summary, Blocking issues, Suggestions, Nits."
    )

def anthropic_review_for_chunks(
    chunks: List[str],
    system_text: str,
    model: str,
    max_tokens: int,
    temperature: float,
    repo_full: str,
    pr_number: int,
    base_sha: str,
    head_sha: str,
) -> Tuple[str, int, int]:
    """
    Sends one request per chunk and concatenates results.
    Returns (combined_text, total_input_tokens, total_output_tokens)
    """
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        log("ANTHROPIC_API_KEY not set; skipping review.")
        return "", 0, 0

    client = anthropic.Anthropic(api_key=api_key)
    combined = []
    total_in = 0
    total_out = 0

    for idx, chunk in enumerate(chunks, start=1):
        user_prompt = (
            f"Repository: {repo_full}\n"
            f"PR: #{pr_number}\n"
            f"Base: {base_sha}\n"
            f"Head: {head_sha}\n"
            f"Chunk {idx}/{len(chunks)} unified diff below. "
            f"Provide a single, self-contained review following the required output format.\n\n"
            f"```diff\n{chunk}\n```"
        )
        try:
            resp = client.messages.create(
                model=model,
                max_tokens=max_tokens,
                temperature=temperature,
                system=system_text,
                messages=[{"role": "user", "content": user_prompt}],
            )
            text_parts = []
            for part in getattr(resp, "content", []):
                if getattr(part, "type", "") == "text":
                    text_parts.append(part.text)
                elif isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
            text = "\n".join([t for t in text_parts if t]).strip()
            if not text:
                text = "_No issues found in this chunk._"
            combined.append(text)

            usage = getattr(resp, "usage", None)
            if usage:
                total_in += getattr(usage, "input_tokens", 0)
                total_out += getattr(usage, "output_tokens", 0)
        except Exception as e:
            log(f"Anthropic call failed for chunk {idx}: {e}")
            combined.append(f"_Error generating review for chunk {idx}: {e}_")

    combined_text = "\n\n---\n\n".join(combined).strip()
    return combined_text, total_in, total_out

def upsert_pr_comment(owner: str, repo: str, pr_number: int, body: str) -> None:
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        log("GITHUB_TOKEN not set; cannot post comment.")
        return

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "claude-code-review-bot",
        }
    )

    # Find existing comment with marker
    list_url = f"https://api.github.com/repos/{owner}/{repo}/issues/{pr_number}/comments?per_page=100"
    existing_id = None
    try:
        resp = session.get(list_url, timeout=30)
        resp.raise_for_status()
        for c in resp.json():
            if isinstance(c, dict) and isinstance(c.get("body", ""), str) and MARKER in c["body"]:
                existing_id = c.get("id")
                break
    except Exception as e:
        log(f"Failed to list comments: {e}")

    if existing_id:
        patch_url = f"https://api.github.com/repos/{owner}/{repo}/issues/comments/{existing_id}"
        try:
            r = session.patch(patch_url, json={"body": body}, timeout=30)
            r.raise_for_status()
            log(f"Updated existing PR comment (id={existing_id}).")
            return
        except Exception as e:
            log(f"Failed to update comment, will try to create new: {e}")

    post_url = f"https://api.github.com/repos/{owner}/{repo}/issues/{pr_number}/comments"
    try:
        r = session.post(post_url, json={"body": body}, timeout=30)
        r.raise_for_status()
        log("Created new PR comment.")
    except Exception as e:
        log(f"Failed to create PR comment: {e}")

def main() -> None:
    event = load_event()
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    owner, repo, base_sha, head_sha, pr_number, labels = get_pr_context(event)

    # Fallback owner/repo from env if missing (e.g., workflow_dispatch)
    if not owner or not repo:
        env_owner, env_repo = get_owner_repo_from_env()
        owner = owner or env_owner
        repo = repo or env_repo

    if event_name == "pull_request":
        repo_full = f"{owner}/{repo}" if owner and repo else ""
        if not all([owner, repo, base_sha, head_sha, pr_number]):
            log("Missing PR context; exiting.")
            sys.exit(0)
    elif event_name == "workflow_dispatch":
        # Manual trigger support: use provided PR number or fall back to latest open PR
        pr_number_env = os.environ.get("PULL_REQUEST_NUMBER") or ""
        pr_data = None
        try:
            if pr_number_env:
                pr_data = fetch_pr(owner, repo, pr_number_env)
            else:
                pr_data = latest_open_pr(owner, repo)
        except Exception as e:
            log(f"Failed to resolve PR for manual run: {e}")
        if not pr_data:
            log("No PR found for manual run; exiting.")
            sys.exit(0)
        pr_number = int(pr_data.get("number"))
        base_sha = pr_data.get("base", {}).get("sha")
        head_sha = pr_data.get("head", {}).get("sha")
        labels = [lbl.get("name") for lbl in pr_data.get("labels", []) if lbl.get("name")]
        repo_full = f"{owner}/{repo}"
    else:
        log(f"Event '{event_name}' not supported; exiting.")
        sys.exit(0)

    # Label gating
    require_label = str(os.environ.get("REQUIRE_LABEL", "false")).lower() in ("1", "true", "yes")
    label_name = os.environ.get("LABEL_NAME", "ai-review")
    if require_label and label_name not in labels:
        log(f"Label gating enabled and label '{label_name}' not present; skipping review.")
        sys.exit(0)

    include_globs = DEFAULT_INCLUDE_GLOBS  # Could be extended to load from config if added later

    try:
        diff_text, included_files = build_filtered_diff(base_sha, head_sha, include_globs)
    except subprocess.CalledProcessError as e:
        log(f"git diff failed: {e.output}")
        sys.exit(0)
    except Exception as e:
        log(f"Failed to build diff: {e}")
        sys.exit(0)

    if not included_files:
        log("No changed files match include patterns; nothing to review.")
        sys.exit(0)

    if not diff_text.strip():
        log("Empty diff; nothing to review.")
        sys.exit(0)

    chunks = split_diff_by_file(diff_text, MAX_CHARS_PER_CHUNK)
    log(f"Preparing review for {len(included_files)} files in {len(chunks)} chunk(s).")

    model = os.environ.get("MODEL", "claude-3-5-haiku-20241022")
    try:
        max_tokens = int(os.environ.get("MAX_TOKENS", "2000"))
    except ValueError:
        max_tokens = 2000
    try:
        temperature = float(os.environ.get("TEMPERATURE", "0"))
    except ValueError:
        temperature = 0.0

    system_text = read_prompt_file()

    review_text, input_tokens, output_tokens = anthropic_review_for_chunks(
        chunks, system_text, model, max_tokens, temperature, repo_full, pr_number, base_sha, head_sha
    )

    if not review_text.strip():
        log("Model returned empty review; skipping comment.")
        sys.exit(0)

    token_meta = ""
    if input_tokens or output_tokens:
        token_meta = f"\n\n_Tokens — input: {input_tokens}, output: {output_tokens}_"

    comment_body = (
        f"### Claude Review (model: {model})\n\n"
        f"{MARKER}\n\n"
        f"{review_text}\n"
        f"{token_meta}"
    )

    upsert_pr_comment(owner, repo, pr_number, comment_body)
    log("Review completed.")
    # Always exit 0 (non-blocking)
    sys.exit(0)

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log(f"Unhandled error: {e}")
        # Do not fail CI
        sys.exit(0)
