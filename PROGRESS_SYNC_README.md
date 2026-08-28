# Progress Sync Jellyfin Image

This packaging repo builds one Jellyfin container image from two modified forks:

- `jellyfin-server`: server changes for saved sync groups and multidirectional progress propagation.
- `jellyfin-web`: web changes for the admin-only show context menu action.

## GitHub Setup

Create three GitHub repositories:

- `jellyfin-server-progress-sync`
- `jellyfin-web-progress-sync`
- `jellyfin-progress-sync-packaging`

Push the local directories to those repositories.

In the `jellyfin-progress-sync-packaging` GitHub repository, add repository variables:

```text
JELLYFIN_SERVER_REPOSITORY=YOUR_GITHUB_USERNAME/jellyfin-server-progress-sync
JELLYFIN_WEB_REPOSITORY=YOUR_GITHUB_USERNAME/jellyfin-web-progress-sync
```

Then run the `Publish progress sync Jellyfin image` workflow.

The image published by the workflow is:

```text
ghcr.io/YOUR_GITHUB_USERNAME/jellyfin-progress-sync:latest
```

## Remote Compose Change

On the Jellyfin server, keep your existing volumes, user, groups, devices, environment, Cloudflare containers, and volume definitions.

Only replace the Jellyfin image:

```yaml
services:
  jellyfin:
    image: ghcr.io/YOUR_GITHUB_USERNAME/jellyfin-progress-sync:latest
```

If the GHCR package is private, log in on the remote Docker host first:

```bash
echo YOUR_GITHUB_TOKEN | docker login ghcr.io -u YOUR_GITHUB_USERNAME --password-stdin
```

Then deploy:

```bash
docker compose pull jellyfin
docker compose up -d jellyfin
```

The feature stores its own config at:

```text
/config/config/progresssync.json
```

With your host mount, that is:

```text
/mnt/pool/nas/jellyfin/config/config/progresssync.json
```

## UI Behavior

Right click a TV show as an admin user:

```text
Sync progress to user
```

Choose a user. Jellyfin adds the current admin user and the selected user to that show's sync group. Selecting an already synced user removes that user from the group.

After that, progress changes made by either synced user on that show's episodes are copied to the other synced users.
