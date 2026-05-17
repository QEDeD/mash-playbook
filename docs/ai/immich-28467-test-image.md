# Immich #28467 Test Image

Temporary test image for validating a possible fix for
https://github.com/immich-app/immich/issues/28467.

## Image

- Base image: `ghcr.io/immich-app/immich-server:v2.7.5`
- Test image tag after loading: `immich-server:v2.7.5-pr-28467-visible-stack-representative`
- Archive: `immich-server-v2.7.5-pr-28467-visible-stack-representative.tar.gz`
- Archive SHA256:
  `767d82cea4727b333ae45b232e86990aecea5cfacc4fbe86f4cd7fcfdeb10109`

The image is the official Immich `v2.7.5` server image with only the compiled
timeline repository file replaced. It does not include a schema migration or API
change.

## Download

Download the archive from the GitHub prerelease:

https://github.com/QEDeD/mash-playbook/releases/tag/immich-28467-v2.7.5-test-image

## Load

```sh
sha256sum immich-server-v2.7.5-pr-28467-visible-stack-representative.tar.gz
docker load -i immich-server-v2.7.5-pr-28467-visible-stack-representative.tar.gz
```

## Docker Compose Override

Set only the Immich server container to the local test image:

```yaml
services:
  immich-server:
    image: immich-server:v2.7.5-pr-28467-visible-stack-representative
    pull_policy: never
```

Then restart only the server:

```sh
docker compose up -d immich-server
```

Rollback is to remove the override and restart `immich-server` with the normal
Immich `v2.7.5` image.
