#!/usr/bin/env bash
# Installs GitHub Actions Runner Controller (ARC) and two autoscaling runner
# pools on the current Kubernetes context:
#   arc-cpu   general builds, scales 0..10, Docker-in-Docker for container jobs
#   arc-gpu   GPU nodes only, runs the CUDA tests for real (scales 0..2)
#
#   GITHUB_PAT=... infra/k8s/arc/install.sh [github-config-url]
#
# The PAT (or better, a GitHub App) needs admin access to the repository to
# register runners. It is stored as a Kubernetes secret, never in this repo.
set -euo pipefail

CONFIG_URL="${1:-https://github.com/7shantanu7/driverforge}"
ARC_VERSION="${ARC_VERSION:-0.12.1}"   # pin; bump deliberately after reading release notes
CHARTS="oci://ghcr.io/actions/actions-runner-controller-charts"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
: "${GITHUB_PAT:?set GITHUB_PAT (or adapt this script to a GitHub App secret)}"

helm upgrade --install arc "$CHARTS/gha-runner-scale-set-controller" \
    --namespace arc-systems --create-namespace --version "$ARC_VERSION" --wait

kubectl create namespace arc-runners --dry-run=client -o yaml | kubectl apply -f -
kubectl -n arc-runners create secret generic github-config \
    --from-literal=github_token="$GITHUB_PAT" --dry-run=client -o yaml | kubectl apply -f -

for pool in cpu gpu; do
    helm upgrade --install "arc-$pool" "$CHARTS/gha-runner-scale-set" \
        --namespace arc-runners --version "$ARC_VERSION" \
        --set githubConfigUrl="$CONFIG_URL" \
        --values "$HERE/values-$pool.yaml" --wait
done

kubectl -n arc-runners get autoscalingrunnersets
echo "Runners register as 'arc-cpu' and 'arc-gpu'. Use them with: runs-on: arc-gpu"
