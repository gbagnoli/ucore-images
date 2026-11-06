# Image repository instructions

- Preserve common-before-host build ordering and exact-revision Skillet artifact
  consumption. Signing remains in the image publication jobs.
- Validate workflow changes with actionlint as well as YAML parsing and shell
  checks. Context availability depends on the workflow key; syntax checks alone
  do not validate GitHub expressions. Use the container pinned in
  `.github/workflows/workflow-lint.yml`; no workstation installation is needed.
- Keep generated bundles and private inputs out of Git.
- Keep version, annotated tag and full commit consistent in `skillet-release.json`.
  Require publication of the reviewed source release before building or publishing
  dependent images; cross-repository changes may be prepared locally. Never replace
  exact commits with moving refs or remove publication/binary identity checks.
