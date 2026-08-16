# syntax=docker/dockerfile:1.26

# Pinned versions tracked by Renovate (regex managers in renovate.json)
# and the daily upstream-tracker.yml workflow. Bump in sync with
# upstream rohitg00/agentmemory's deploy/fly/Dockerfile.
ARG III_VERSION=0.22.1

FROM iiidev/iii:${III_VERSION} AS iii-image

FROM node:24-slim

ARG AGENTMEMORY_VERSION=0.9.29
ARG III_VERSION=0.22.1
ARG III_SDK_VERSION=0.22.1

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates tini gosu curl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=iii-image /app/iii /usr/local/bin/iii

# iii spawns a separate `iii-worker` binary for the iii-queue worker, and it is
# NOT shipped inside iiidev/iii. At runtime `iii` would try to fetch it itself,
# which cannot work here for two reasons:
#   - it resolves the asset for its OWN target triple. iii <= 0.21.6 published
#     an amd64 musl build, and iii-hq/iii has never released an iii-worker for
#     x86_64-unknown-linux-musl (only *-linux-gnu and *-apple-darwin), so the
#     download 404s with "Release asset not found for platform".
#   - a self-download at boot makes the image non-reproducible: it silently
#     changes behaviour per pull, which is exactly how the old 0.9.27 tag ended
#     up alive on one node and broken on another.
# So bake the gnu worker in at build time. This base is node:24-slim (glibc),
# so the *-linux-gnu build is the correct one for both architectures.
ARG TARGETARCH
RUN set -eu; \
    case "${TARGETARCH}" in \
      amd64) III_TRIPLE=x86_64-unknown-linux-gnu ;; \
      arm64) III_TRIPLE=aarch64-unknown-linux-gnu ;; \
      *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    BASE="https://github.com/iii-hq/iii/releases/download/iii/v${III_VERSION}"; \
    curl -fsSL -o /tmp/iii-worker.tar.gz "${BASE}/iii-worker-${III_TRIPLE}.tar.gz"; \
    curl -fsSL -o /tmp/iii-worker.sha256 "${BASE}/iii-worker-${III_TRIPLE}.sha256"; \
    printf '%s  /tmp/iii-worker.tar.gz\n' "$(cut -d' ' -f1 /tmp/iii-worker.sha256)" | sha256sum -c -; \
    tar xzf /tmp/iii-worker.tar.gz -C /usr/local/bin iii-worker; \
    chmod 0755 /usr/local/bin/iii-worker; \
    rm -f /tmp/iii-worker.tar.gz /tmp/iii-worker.sha256; \
    # iii only looks in ~/.local/bin, not on PATH, and the entrypoint execs as
    # `node`, so mirror the binary into that user's home.
    install -d -o node -g node /home/node/.local/bin; \
    ln -s /usr/local/bin/iii-worker /home/node/.local/bin/iii-worker; \
    /usr/local/bin/iii-worker --version || true

WORKDIR /opt/agentmemory

# iii 0.22 added a 'configuration' worker that creates ./config relative to its
# CWD. The entrypoint execs as `node` while WORKDIR is root-owned, so without
# this it dies on startup with:
#   failed to create worker 'configuration': failed to create configuration
#   directory './config': Permission denied (os error 13)
# Upstream's own iiidev/iii image sidesteps this by shipping /app/config and
# /app/data pre-created; do the same for our WORKDIR.
RUN install -d -o node -g node /opt/agentmemory/config /opt/agentmemory/data
RUN printf '{"name":"agentmemory-deploy","version":"1.0.0","private":true,"overrides":{"iii-sdk":"%s"}}\n' "${III_SDK_VERSION}" > package.json \
 && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" --omit=optional --no-fund --no-audit \
 && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory

ENV AGENTMEMORY_III_VERSION=${III_VERSION} \
    TINI_SUBREAPER=1 \
    AGENTMEMORY_DATA_DIR=/data \
    AGENTMEMORY_VIEWER_HOST=0.0.0.0 \
    VIEWER_ALLOWED_HOSTS=memory-ui.k8s.one,localhost:3113,127.0.0.1:3113

# Verbatim copy of upstream's deploy/fly/entrypoint.sh.
# Kept in sync by .github/workflows/upstream-tracker.yml.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/agentmemory-entrypoint.sh

EXPOSE 3111 3113

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agentmemory-entrypoint.sh"]
