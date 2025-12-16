#!/bin/bash
# SPDX-FileCopyrightText: 2022 Demerzel Solutions Limited
# SPDX-License-Identifier: LGPL-3.0-only

set -euo pipefail

echo "Publishing packages to GitHub"

release_id=$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$GITHUB_REPOSITORY/releases \
  | jq -r '.[] | select(.tag_name == "'$GIT_TAG'") | .id')

should_publish=true

if [[ -z "$release_id" ]]; then
  echo "Drafting release $GIT_TAG"

  relnotes=$(cat <<'EOF'
# Release notes

### [CONTENT PLACEHOLDER]

#### Build signatures

The packages are signed with the following OpenPGP key: `AD12 7976 5093 C675 9CD8 A400 24A7 7461 6F1E 617E`
EOF
)

  release_id=$(printf '%s' "$relnotes" | gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$GITHUB_REPOSITORY/releases \
    -f 'tag_name=$GIT_TAG' \
    -f 'target_commitish=$GITHUB_SHA' \
    -f 'name=v$GIT_TAG' \
    -F "draft=true" \
    -F "prerelease=$PRERELEASE" \
    -F body=@- \
    | jq -r '.id')

  should_publish=false
fi

cd $GITHUB_WORKSPACE/$PACKAGE_DIR

for file_name in *.zip *.zip.asc; do
  echo "Uploading $file_name"

  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$GITHUB_REPOSITORY/releases/$release_id/assets?name=$file_name \
    -f '@$file_name'
done

if [[ "$should_publish" == "true" ]]; then
  echo "Publishing release $GIT_TAG"

  make_latest=$([[ "$PRERELEASE" == "true" ]] && echo "false" || echo "true")

  gh api \
    --method PATCH \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    /repos/$GITHUB_REPOSITORY/releases/$release_id \
    -f 'target_commitish=$GITHUB_SHA' \
    -f 'name=v$GIT_TAG' \
    -F "draft=false" \
    -F "make_latest=$make_latest" \
    -F "prerelease=$PRERELEASE"
fi

echo "Publishing completed"
