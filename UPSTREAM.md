# Upstream provenance

This image is a downstream rebuild of [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

| File           | Source                                                    | Sync policy                                    |
|----------------|-----------------------------------------------------------|------------------------------------------------|
| Dockerfile     | adapted from `deploy/fly/Dockerfile` at the pinned tag    | manual + upstream-tracker.yml                  |
| entrypoint.sh  | verbatim copy of `deploy/fly/entrypoint.sh`               | upstream-tracker.yml opens PR on diff          |

Downstream-only modifications live exclusively in the Dockerfile (ENV
vars enabling viewer bind for Kubernetes). `entrypoint.sh` is kept
byte-for-byte identical to upstream.
