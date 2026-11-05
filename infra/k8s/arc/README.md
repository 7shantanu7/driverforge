# Self-hosted, autoscaling CI runners on Kubernetes

GitHub-hosted runners have no GPU, so CI can only *build* the CUDA backend.
To *run* GPU tests, this sets up [Actions Runner Controller (ARC)][arc] on a
Kubernetes cluster with two runner pools:

| Pool | Runs on | Scales | Used by |
| --- | --- | --- | --- |
| `arc-cpu` | any node | 0 to 10 | any job that sets `runs-on: arc-cpu` |
| `arc-gpu` | NVIDIA GPU nodes, 1 GPU per job | 0 to 2 | `.github/workflows/gpu-tests.yml` |

Both pools create a fresh pod per job and scale to zero when idle. A job
never sees state from a previous job, which is the main reason to prefer
ephemeral runners over long-lived build machines.

## Install

Prerequisites: a cluster with `kubectl` and `helm` access. For the GPU pool,
the cluster also needs the [NVIDIA GPU Operator][gpu-operator], which adds
the `nvidia.com/gpu` resource, the `nvidia.com/gpu.present` node label and
the `nvidia` RuntimeClass.

```bash
GITHUB_PAT=<token with repo admin> infra/k8s/arc/install.sh
```

For production, use a GitHub App instead of a personal access token. It has
narrower permissions and does not depend on one person's account.

## Run the GPU tests

Start the "gpu-tests" workflow from the Actions tab. It runs only when
started by hand, so CI never waits for a GPU runner that does not exist.

[arc]: https://github.com/actions/actions-runner-controller
[gpu-operator]: https://github.com/NVIDIA/gpu-operator
