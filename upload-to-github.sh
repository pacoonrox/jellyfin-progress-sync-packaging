#!/bin/sh
set -eu

OWNER="${GITHUB_OWNER:-pacoonrox}"
VISIBILITY="${GITHUB_VISIBILITY:-private}"

SERVER_REPO="jellyfin-server-progress-sync"
WEB_REPO="jellyfin-web-progress-sync"
PACKAGING_REPO="jellyfin-progress-sync-packaging"

create_repo() {
    repo="$1"
    if gh repo view "$OWNER/$repo" >/dev/null 2>&1; then
        echo "$OWNER/$repo already exists"
        return
    fi

    gh repo create "$OWNER/$repo" "--$VISIBILITY"
}

push_repo() {
    path="$1"
    repo="$2"

    cd "$path"
    git remote set-url origin "https://github.com/$OWNER/$repo.git"
    git push -u origin master
}

gh auth status

create_repo "$SERVER_REPO"
create_repo "$WEB_REPO"
create_repo "$PACKAGING_REPO"

push_repo /home/dak/jellyfin-server-progress-sync "$SERVER_REPO"
push_repo /home/dak/jellyfin-web-progress-sync "$WEB_REPO"
push_repo /home/dak/jellyfin-progress-sync-packaging "$PACKAGING_REPO"

gh variable set JELLYFIN_SERVER_REPOSITORY \
    --repo "$OWNER/$PACKAGING_REPO" \
    --body "$OWNER/$SERVER_REPO"

gh variable set JELLYFIN_WEB_REPOSITORY \
    --repo "$OWNER/$PACKAGING_REPO" \
    --body "$OWNER/$WEB_REPO"

gh workflow run publish-progress-sync-image.yml \
    --repo "$OWNER/$PACKAGING_REPO" \
    --ref master

echo "Upload complete. Watch the image build at:"
echo "https://github.com/$OWNER/$PACKAGING_REPO/actions"
echo
echo "When it finishes, your Docker image will be:"
echo "ghcr.io/$OWNER/jellyfin-progress-sync:latest"
