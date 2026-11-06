# linkforge-gitops

The **deployment repo** for [linkforge](https://github.com/Saicharan519/linkforge): the only place
that says what runs in a cluster. Application code and CI live in the other repo; CI builds and
pushes images, then commits the new image tag here. Argo CD (from P1S.5) watches this repo and
makes the cluster match it, so a deploy is a commit and a rollback is `git revert`.

```
charts/linkforge/      the Helm chart: templates for API, frontend, migration Job, (kind) Postgres, Ingress
envs/kind/values.yaml  what differs on the local kind cluster, including the image tags
envs/eks/values.yaml   (later) the same for EKS: never share one values file between environments
```

## Rules

- `envs/<env>/values.yaml` holds the two lines `tag: "sha-..." # ci:api-tag` and
  `# ci:frontend-tag`. **CI rewrites them**: keep the markers and the `tag: "..."` shape.
- No secrets in this repo. The database secret is created by hand for now (Sealed Secrets later).
- Check changes offline before committing:

```bash
helm lint charts/linkforge -f envs/kind/values.yaml
helm template linkforge charts/linkforge -n linkforge -f envs/kind/values.yaml
```
