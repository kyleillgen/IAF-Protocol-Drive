# Upstream relationship

The Drive variant starts from IAF Protocol Portable v0.2.1, commit `54b3c4ac23a852feae1b89d48b4830708cfbfcee`.

It is a separate derivative repository, with shared clean Git history, rather than a GitHub fork inside the same owner account. Use the base repository as upstream when merging fixes:

```sh
git remote add upstream https://github.com/kyleillgen/IAF-Protocol.git
git fetch upstream --tags
git merge upstream/main
```

If upstream is already configured, reuse it. Review conflicts and run both suites before merging or releasing. The variant's README and extension docs intentionally differ; `packages/portable` remains the upstream package. Do not assume a new base version is compatible: update the extension's version check and record the tested base commit deliberately.

Keep base fixes in IAF Protocol, then merge them here. Google-specific code belongs in packages/google-drive. The private installation repository is not an upstream and must never be pushed into this public history. This rename updates public branding and compatible entry points in both repositories; it does not pull deployment 0.3.0 into the Drive preview.
