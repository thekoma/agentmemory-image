# syntax=docker/dockerfile:1.25

# Pinned versions tracked by Renovate (regex managers in renovate.json)
# and the daily upstream-tracker.yml workflow. Bump in sync with
# upstream rohitg00/agentmemory's deploy/fly/Dockerfile.
ARG III_VERSION=0.11.2

FROM iiidev/iii:${III_VERSION} AS iii-image

FROM node:24-slim

ARG AGENTMEMORY_VERSION=0.9.27
ARG III_VERSION=0.11.2
ARG III_SDK_VERSION=0.11.2

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates tini gosu curl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=iii-image /app/iii /usr/local/bin/iii

WORKDIR /opt/agentmemory
RUN printf '{"name":"agentmemory-deploy","version":"1.0.0","private":true,"overrides":{"iii-sdk":"%s"}}\n' "${III_SDK_VERSION}" > package.json \
 && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" --omit=optional --no-fund --no-audit \
 && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory

ENV AGENTMEMORY_III_VERSION=${III_VERSION} \
    TINI_SUBREAPER=1 \
    AGENTMEMORY_VIEWER_HOST=0.0.0.0 \
    VIEWER_ALLOWED_HOSTS=memory-ui.k8s.one,localhost:3113,127.0.0.1:3113

# Verbatim copy of upstream's deploy/fly/entrypoint.sh.
# Kept in sync by .github/workflows/upstream-tracker.yml.
COPY --chmod=0755 entrypoint.sh /usr/local/bin/agentmemory-entrypoint.sh

EXPOSE 3111 3113

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agentmemory-entrypoint.sh"]
