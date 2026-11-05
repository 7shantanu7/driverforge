# Local Jenkins

Runs a Jenkins controller with the `gpu-driver-stack` multibranch pipeline
already configured (Configuration as Code and Job DSL, no clicking through
the setup wizard). The pipeline itself is the repository's `Jenkinsfile`.

```bash
export JENKINS_ADMIN_PASSWORD='choose-a-password'
docker compose -f infra/jenkins/docker-compose.yml up --build
```

Open http://localhost:8080 and sign in as `admin`. Jenkins scans the
repository every 5 minutes and builds every branch. To build a fork or a
local mirror, set `REPO_URL` before `docker compose up`.

How it fits together:

- `Dockerfile` is the controller image (Jenkins LTS plus the Docker CLI).
- `plugins.txt` pins the plugins the pipeline needs.
- `casc/jenkins.yaml` creates the admin user and the multibranch job.
- The `Jenkinsfile` stages run in containers built from `Dockerfile.dev`
  on the host Docker daemon, so Jenkins, GitHub Actions and GitLab CI all
  build in the same image with the same scripts.

Mounting the Docker socket gives the controller root-equivalent access to
the host. That is acceptable for a local demo. A production setup would use
separate build agents, for example ephemeral Kubernetes pods.
