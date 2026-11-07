# Sealed Secrets controller (vendored, pinned)

`controller.yaml` is the upstream release manifest of **bitnami-labs/sealed-secrets v0.41.2**
(GitHub release asset `controller.yaml`), committed here so that Argo CD installs exactly this and
nothing can change underneath us. (This is the Sealed Secrets CONTROLLER; the rule "no Bitnami charts"
is about Postgres and Redis.)

| What | Value |
|---|---|
| Upstream file sha256 (as downloaded 2026-11-07) | `5973b18ef77ae91e464bac62542a12c48844a08da69d80e45a8fc7f0d67fe205` |
| This file sha256 (after the two edits below) | `89e26892174bc4ec3e88b9214bf32f1f234be38b9b15352bf84b42bfba373e79` |
| Controller image | `docker.io/bitnami/sealed-secrets-controller:0.41.2@sha256:e63ec6ec2b12a471bf781081bd370a93ca7b7b3999e5b9243341379aeb801d0b` |
| `kubeseal` CLI | 0.41.2, its tarball's sha256 was verified against the project's `checksums.txt` |

The project does NOT publish a checksum for `controller.yaml` itself; the hash above is the one we
observed, so a future download can be compared with it.

## Our two edits (everything else is byte-for-byte upstream; `diff` against the release asset shows only these)
1. The image is pinned by **digest** as well as by tag (a tag can be re-pointed, a digest cannot).
2. The CRD carries `argocd.argoproj.io/sync-options: Prune=false,Delete=false`. Deleting the
   `SealedSecret` CRD would delete every SealedSecret, and Kubernetes would then delete the Secrets they
   created: the whole application would lose its database password. Argo CD must never do that on its own.

## Known finding (accepted, documented in D78)
Trivy (the CI gate's command) reports one HIGH in the controller image: `golang.org/x/net`
v0.60.0, CVE-2026-78661 (denial of service through crafted HTML, fixed in 0.62.0). This is the newest
upstream release, so there is no fixed image to move to; the controller never parses HTML from outside
the cluster. CI does not scan third-party images, so no gate fails. Re-check on every new release.

## Update procedure
1. `gh release download vX.Y.Z -R bitnami-labs/sealed-secrets -p controller.yaml`, compare with the hashes above.
2. Re-apply the two edits (new image digest from `docker pull` + `docker inspect`).
3. Scan the image (`trivy image --severity HIGH,CRITICAL --ignore-unfixed <image>`), update this table, open a pull request.
4. Update `kubeseal` to the same version.
