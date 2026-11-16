# DeployReady: Kora Analytics API

A Node.js API that is containerised, tested and deployed to AWS automatically on every push to `main`, with a health check that rolls back bad releases.

**Live:** http://54.171.149.85/health

Kora Analytics used to deploy by SSHing into a server and restarting the app by hand, with no tests and no way to know a release had broken. This project replaces that with Docker, a GitHub Actions pipeline and an AWS EC2 server. The application code in `app/` was provided and is unchanged.

## Architecture

```
 git push main ──► GitHub Actions
                     ├─ Test     npm ci + npm test
                     ├─ Build    docker build → push to ghcr.io (tag = commit SHA)
                     └─ Deploy   OIDC → AWS role → open SSH for runner IP
                                 → pull & restart container → GET /health
                                 → fail? roll back to previous image
                                 → always close SSH

 User ──► 54.171.149.85:80 ──► Security group ──► EC2 (Ubuntu, Docker)
                                                  └─► container :3000, non-root
```

**Tools:** Docker, Docker Compose, GitHub Actions, GitHub Container Registry, AWS (EC2, Security Groups, Elastic IP, IAM/OIDC, CloudTrail).

## Run locally

```bash
cp .env.example .env
docker compose up --build
curl http://localhost:3000/health     # {"status":"ok"}
```

Tests: `cd app && npm ci && npm test`

## Key decisions

- **Build once, deploy the same image:** CI builds and pushes the image; the server only pulls it. Tags are commit SHAs, so every release is traceable and rollback means running the previous SHA.
- **Non-root, multi-stage image:** only production dependencies ship, and the app runs as the `node` user.
- **No stored cloud credentials:** GitHub assumes an AWS role through OIDC, and that role can only add or remove rules on one security group.
- **SSH stays locked down:** port 22 is open to the admin IP only; the pipeline opens it for its own IP during a deploy and always closes it.
- **Automatic rollback:** if `/health` fails after a deploy, the previous image is restored and the run fails. This was tested with a deliberately broken release.

## Documentation

[DEPLOYMENT.md](DEPLOYMENT.md) covers the AWS setup, the pipeline, rollback, logs, observability, troubleshooting and known limitations.
