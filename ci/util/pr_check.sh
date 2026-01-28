#!/usr/bin/env bash
set -euo pipefail

# List open, non-draft PRs that are REVIEW_REQUIRED, grouped by "last updated" age buckets:
#
# ### > 1 Month
# ### > 1 Week
# ### > 1 Day
# ### Last 24h
#
# Each PR line (Slack-friendly):
#   • [c, cmake, cccl, cudax, infra, python] https://github.com/NVIDIA/cccl/pull/5315 "[STF] Add python bindings"
#
# Notes:
#   - CODEOWNER reviewer names are normalized by:
#       1) stripping a trailing "-codeowners"
#       2) stripping a leading "cccl-"
#   - Requires: gh, jq, GNU date (this uses: date -d)
#
# Usage:
#   ./pr_check.sh OWNER REPO
#
# Example:
#   ./pr_check.sh NVIDIA cccl

OWNER="${1:-}"
REPO="${2:-}"

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  echo "Usage: $0 OWNER REPO" >&2
  exit 2
fi

for cmd in gh jq date; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Error: ${cmd} not found in PATH" >&2
    exit 1
  fi
done

read -r -d '' Q_PRS <<'GRAPHQL' || true
query($owner:String!, $name:String!, $cursor:String) {
  repository(owner:$owner, name:$name) {
    pullRequests(
      states: OPEN,
      first: 50,
      after: $cursor,
      orderBy: {field: UPDATED_AT, direction: DESC}
    ) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        url
        isDraft
        reviewDecision
      updatedAt
      author { login }
      }
    }
  }
}
GRAPHQL

read -r -d '' Q_CODEOWNER_REQUESTS <<'GRAPHQL' || true
query($owner:String!, $name:String!, $number:Int!, $cursor:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewRequests(first: 50, after: $cursor) {
        pageInfo { hasNextPage endCursor }
        nodes {
          asCodeOwner
          requestedReviewer {
            ... on User { login }
            ... on Team { slug name }
          }
        }
      }
    }
  }
}
GRAPHQL

fetch_open_prs_json_lines() {
  local cursor="null"
  while :; do
    local resp
    if [[ "${cursor}" == "null" ]]; then
      resp="$(gh api graphql -f owner="${OWNER}" -f name="${REPO}" -f query="${Q_PRS}")"
    else
      resp="$(gh api graphql -f owner="${OWNER}" -f name="${REPO}" -f cursor="${cursor}" -f query="${Q_PRS}")"
    fi

    echo "${resp}" | jq -c '.data.repository.pullRequests.nodes[]'

    local has_next end_cursor
    has_next="$(echo "${resp}" | jq -r '.data.repository.pullRequests.pageInfo.hasNextPage')"
    end_cursor="$(echo "${resp}" | jq -r '.data.repository.pullRequests.pageInfo.endCursor // empty')"

    if [[ "${has_next}" != "true" || -z "${end_cursor}" ]]; then
      break
    fi
    cursor="${end_cursor}"
  done
}

fetch_codeowner_requests_for_pr() {
  local pr_number="$1"
  local cursor="null"
  local all='[]'

  while :; do
    local resp
    if [[ "${cursor}" == "null" ]]; then
      resp="$(gh api graphql -f owner="${OWNER}" -f name="${REPO}" -F number="${pr_number}" -f query="${Q_CODEOWNER_REQUESTS}")"
    else
      resp="$(gh api graphql -f owner="${OWNER}" -f name="${REPO}" -F number="${pr_number}" -f cursor="${cursor}" -f query="${Q_CODEOWNER_REQUESTS}")"
    fi

    local batch
    batch="$(echo "${resp}" | jq -c '
      .data.repository.pullRequest.reviewRequests.nodes
      | map(select(.asCodeOwner == true))
      | map(
          if (.requestedReviewer | has("slug")) then .requestedReviewer.slug
          else .requestedReviewer.login
          end
        )
      | map(
          gsub("-codeowners$"; "")
          | sub("^cccl-"; "")
        )
    ')"

    all="$(jq -c -n --argjson a "${all}" --argjson b "${batch}" '$a + $b | unique | sort')"

    local has_next end_cursor
    has_next="$(echo "${resp}" | jq -r '.data.repository.pullRequest.reviewRequests.pageInfo.hasNextPage')"
    end_cursor="$(echo "${resp}" | jq -r '.data.repository.pullRequest.reviewRequests.pageInfo.endCursor // empty')"

    if [[ "${has_next}" != "true" || -z "${end_cursor}" ]]; then
      break
    fi
    cursor="${end_cursor}"
  done

  echo "${all}"
}

now_epoch="$(date +%s)"

tmp_dir="/tmp/gh-pr-review-needed-${OWNER}-${REPO}"
mkdir -p "${tmp_dir}"
out_tsv="${tmp_dir}/prs.tsv"
: > "${out_tsv}"

# Collect: updated_epoch<TAB>age_seconds<TAB>rendered_line
while IFS= read -r pr; do
  is_draft="$(echo "${pr}" | jq -r '.isDraft')"
  decision="$(echo "${pr}" | jq -r '.reviewDecision // "NONE"')"

  if [[ "${is_draft}" == "true" ]]; then
    continue
  fi
  if [[ "${decision}" != "REVIEW_REQUIRED" ]]; then
    continue
  fi

  number="$(echo "${pr}" | jq -r '.number')"
  title="$(echo "${pr}" | jq -r '.title')"
  url="$(echo "${pr}" | jq -r '.url')"
  updated_at="$(echo "${pr}" | jq -r '.updatedAt')"
  author_login="$(echo "${pr}" | jq -r '.author.login // "unknown"')"

  updated_epoch="$(date -d "${updated_at}" +%s)"
  age_seconds="$(( now_epoch - updated_epoch ))"
  if (( age_seconds < 0 )); then
    age_seconds=0
  fi

  codeowners_json="$(fetch_codeowner_requests_for_pr "${number}")"
  codeowners_list="$(echo "${codeowners_json}" | jq -r '
    if length == 0 then ""
    else join(",")
    end
  ')"

  # line="• ${url} \"${title_esc}\" (\`@${author_login}\`) [${codeowners_list}]"
  line="• [${author_login}:${codeowners_list}] ${url} "

  min_title_chars=10
  max_line_chars=120
  line_chars=${#line}
  title_chars=${#title}

  if ((line_chars + title_chars > max_line_chars)); then
    target_chars=$((max_line_chars - line_chars))
    if ((target_chars < min_title_chars)); then
      target_chars=$min_title_chars
    fi
    title="$(printf '%s' "$title" | cut -c "1-$((target_chars-3))")..."
  fi

  title_esc="${title//\"/\\\"}"

  line="${line}${title_esc}"

  printf "%s\t%s\t%s\n" "${updated_epoch}" "${age_seconds}" "${line}" >> "${out_tsv}"
done < <(fetch_open_prs_json_lines)

emit_bucket() {
  local heading="$1"
  local min_age="$2" # inclusive
  local max_age="$3" # exclusive (use -1 for infinity)

  echo "${heading}"
  echo
  local count filter_awk
  if [[ "${max_age}" -lt 0 ]]; then
    filter_awk='($2 >= min){print $0}'
    count="$(awk -F'\t' -v min="${min_age}" '($2 >= min){c++} END{print c+0}' "${out_tsv}")"
  else
    filter_awk='($2 >= min && $2 < max){print $0}'
    count="$(awk -F'\t' -v min="${min_age}" -v max="${max_age}" '($2 >= min && $2 < max){c++} END{print c+0}' "${out_tsv}")"
  fi

  if [[ "${count}" -eq 0 ]]; then
    echo "_(none)_"
    echo
    return 0
  fi

  awk -F'\t' -v min="${min_age}" -v max="${max_age}" "${filter_awk}" "${out_tsv}" \
    | sort -t $'\t' -k1,1nr \
    | cut -f3-
  echo
}

sec_day=$((24*60*60))
sec_week=$((7*sec_day))
sec_month=$((30*sec_day))

emit_bucket "> 30d since update" "${sec_month}" -1
emit_bucket "> 7d since update"  "${sec_week}"  "${sec_month}"
emit_bucket "> 1d since update"  "${sec_day}"   "${sec_week}"
emit_bucket "New updates"        0              "${sec_day}"
