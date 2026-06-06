# Upstream provenance

This image is a downstream rebuild of [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).

| File           | Source                                                    | Sync policy                                    |
|----------------|-----------------------------------------------------------|------------------------------------------------|
| Dockerfile     | adapted from `deploy/fly/Dockerfile` at the pinned tag    | manual + upstream-tracker.yml                  |
| entrypoint.sh  | verbatim copy of `deploy/fly/entrypoint.sh`               | upstream-tracker.yml opens PR on diff          |

Downstream-only modifications live exclusively in the Dockerfile (ENV
vars enabling viewer bind for Kubernetes). `entrypoint.sh` is kept
byte-for-byte identical to upstream.

## Why the tracker only watches `III_VERSION`

Upstream `rohitg00/agentmemory` publishes new npm versions of
`@agentmemory/agentmemory` regularly but updates `deploy/fly/Dockerfile`
rarely. At time of writing, npm latest is `0.9.26` while upstream's
Dockerfile still pins `AGENTMEMORY_VERSION=0.9.12`.

Following upstream's Dockerfile pin for `AGENTMEMORY_VERSION` would mean
running 14 versions behind npm. Instead:

- `AGENTMEMORY_VERSION` is bumped by Renovate via the npm datasource
  (custom regex manager in `renovate.json`). Latest npm wins.
- `III_VERSION` is bumped by `upstream-tracker.yml` against the upstream
  Dockerfile. Upstream's iii pin is "load-bearing" — they change it
  deliberately because of the iii ≥ 0.11.6 architectural break documented
  in their own Dockerfile and docker-compose.yml comments. When they
  bump it, our tracker mirrors it (and re-vendors `entrypoint.sh` at the
  same time, since upstream usually changes both together).
