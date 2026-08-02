# CloudLaunchpad

> Turns an empty AWS account into a production-ready environment in under 15 minutes, with one command.

```bash
./launch.sh --env production --app myapp --region us-east-1
```

**Status:** Phase 1 of 3 in progress — networking, CI/CD, and the container image are live; compute and data layers are next. See [Project status](#project-status).

---

## The problem

Every new AWS project burns 2-3 days on the same repetitive setup: VPC, subnets, routing, IAM, a container platform, a database, secrets wiring, CI/CD, monitoring. The work is identical every time — and because it's done by hand, it's subtly different every time. Then nobody can say precisely what's deployed, or rebuild it.

CloudLaunchpad makes it 15 reproducible minutes, defined entirely in code.

## What it does

A single command provisions a complete, working environment:

- A VPC with public and private subnets across two availability zones
- A containerized FastAPI service on ECS Fargate behind an Application Load Balancer
- PostgreSQL and Valkey in private subnets, credentials injected at runtime and never written to code
- A React dashboard on CloudFront, behind Cognito authentication enforced at the load balancer
- CI/CD via GitHub Actions using OIDC — no long-lived AWS credentials exist anywhere
- CloudWatch dashboards and alarms wired to real service-level indicators from the first deploy

The FastAPI application is deliberately small. It is the vehicle for the infrastructure, not the product.

---

## Architecture

```
CloudFront + WAF
    └── S3 static site (React dashboard)
            └── Application Load Balancer  ──authenticate-cognito──> Cognito user pool
                    └── ECS Fargate (FastAPI)
                            ├── RDS PostgreSQL    (private subnet)
                            └── ElastiCache Valkey (private subnet)
```

Outbound traffic uses VPC gateway endpoints rather than a NAT Gateway — see [Design decisions](#design-decisions).

### Stack

| Layer | Choice | Why |
|-------|--------|-----|
| Compute | ECS Fargate | No instances to patch or scale, per-second billing, and the task definition is a clean unit of deployment |
| IaC | Terraform, modular | Every module has a single responsibility and is independently testable |
| CI/CD | GitHub Actions + OIDC | Federated short-lived credentials; nothing static to leak or rotate |
| Application | FastAPI (Python) | Async native, typed, and a JSON API with almost no framework overhead |
| Database | RDS PostgreSQL | Private subnet, no public endpoint |
| Cache | ElastiCache Valkey | A cache shared across tasks, so replicas can't disagree — see below |
| Frontend | Vite + React | Built artifact, so CI demonstrates a real asset pipeline into S3 |
| Static hosting | S3 + CloudFront + WAF | Origin Access Control, managed WAF rule groups at the edge |
| Authentication | Cognito, via the ALB | The load balancer completes the auth flow before traffic reaches the app |
| Config | SSM Parameter Store | Non-sensitive parameters, cheap at any volume |
| Secrets | Secrets Manager | Database credential only, with automatic rotation |
| Monitoring | CloudWatch + SNS | Alarms on error rate and p95 latency, not on CPU |

---

## Design decisions

The parts worth defending, and the alternatives they were chosen over.

### Cost is a design constraint, not an afterthought

This project runs under a **$10/month ceiling**. That number changed the architecture more than any technical preference did, working inside it produced better decisions than an unlimited budget would have.

Left running continuously the stack costs roughly $85-90/month. Applied only while being worked on, it costs about $8. So everything is billed per hour or per request, and everything is destroyed at the end of every session. The permanent footprint — the Terraform state bucket, the container registry, and log groups — stays under $1/month.

### No NAT Gateway

A NAT Gateway costs ~$32/month — a third of the entire budget — to solve a problem this workload barely has. Instead, S3 and ECR traffic goes through **VPC gateway endpoints**, which are free, with interface endpoints added only where something genuinely needs them.

Endpoint traffic never leaves the AWS network, which is both cheaper and more defensible than routing it out through a managed NAT.

### Secrets Manager for one secret, SSM for everything else

The usual advice is "SSM is cheap, Secrets Manager is expensive, use SSM." That holds right up until you need rotation, which SSM has no native support for.

So the split follows the actual requirement: **Secrets Manager for the database credential**, where weekly rotation justifies $0.40/month, and **SSM Parameter Store for all non-sensitive configuration**. Paying for a managed service on one item is cheaper than building and maintaining a rotation mechanism for everything.

### Why a cache exists at all

A cache on a project with no users is easy to write off as decoration, so the justification has to be something other than speed.

`GET /metrics` is backed by CloudWatch `GetMetricData`, which is **billed per metric requested and rate-limited**. A dashboard polling every 5 seconds against three Fargate tasks is 36 upstream calls a minute. Cached with a 60-second TTL, it's one. That's a cost and quota argument, and it holds at zero traffic — which the latency argument does not.

The second reason is the one that actually decides the design: **an in-process cache breaks the moment there is more than one task.** Two replicas with local dictionaries serve different numbers for the same question and double the upstream calls. A shared cache is the correct answer as soon as you run more than one replica — which a rolling deploy requires by definition.

The interesting question was never how to cache, but what tolerates being stale, and for how long.

### Valkey over Redis and Memcached

**Memcached** is a pure LRU cache: multi-threaded, no data structures, no persistence. Its advantage is raw throughput per node, which is irrelevant here, and its cost is ruling out atomic counters — so rate limiting and anything Phase 4 might need would have to move elsewhere.

**Valkey** is the Redis fork maintained under the Linux Foundation after the 2024 licence change, API-compatible and priced below Redis OSS on ElastiCache. Same data structures, same client libraries, lower bill. Node-based `cache.t4g.micro`, not serverless — ElastiCache Serverless has a minimum capacity floor that exceeds this project's entire monthly budget.

### React for a dashboard, deliberately

A single page reading two endpoints does not need React, and choosing it anyway needs a reason.

The reason is that the **build step is the point**. A framework-free page is `aws s3 sync` and nothing is demonstrated. A built artifact means CI has to compile assets, sync them to S3, and invalidate the CloudFront distribution in the right order — which is the deployment pattern any real frontend needs, and one more thing that has to work before the deploy is green.

The cost is a Node toolchain in CI. That's accepted here because the same toolchain is already needed elsewhere.

### Authentication at the load balancer

The ALB's native `authenticate-cognito` action completes the OIDC flow with a Cognito user pool and only then forwards the request, with the user's claims attached as headers. No API Gateway is required, and no authentication code exists in the application at all.

The tradeoff is portability: this ties the auth flow to the ALB, so moving to API Gateway later means moving to a JWT authorizer. That is a real cost, accepted because the alternative — hand-written token validation — is the single most dangerous code to get subtly wrong.

### One Terraform root, one environment

Docker Compose is the development environment. An AWS `dev` environment would double every hourly charge to reproduce what already runs locally for free, so it is never applied — the application stays portable to one, the infrastructure does not pretend to have one.

If a second environment ever becomes genuinely necessary, it will be directories rather than Terraform workspaces: workspaces share a backend, are easy to apply against by mistake, and are explicitly not recommended for separating production.

### EC2 before Fargate

The first compute implementation is a plain EC2 instance bootstrapped with cloud-init `user_data` — deliberately, and it gets thrown away. Building the manual version first is what makes the argument for Fargate concrete rather than received: instance patching, user-data debugging, and the absence of rolling deploys are much more persuasive after you've dealt with them.

### No automated database backups

Deliberate, and only defensible in this context: the environment is destroyed after every session and holds no data whose loss matters. In a real system this would be indefensible, which is exactly why it's written down rather than left as a silent gap.

---

## Engineering concepts demonstrated

What building this required understanding, beyond wiring resources together.

**Identity federation.** The same STS `AssumeRole` mechanism appears three times in different clothing — GitHub Actions via OIDC web identity, EC2 via instance profiles, and (in Phase 2) Kubernetes service accounts via IRSA. Recognizing them as one pattern is most of the learning.

**The bootstrap problem.** Terraform needs a remote state backend, and the state backend is itself infrastructure. `bootstrap/` resolves the circular dependency by creating the S3 bucket once, out of band, before `terraform init` can run.

**Terraform resource addressing.** `count` keys resources by index, so deleting the middle element silently re-creates everything after it; `for_each` keys by a stable value and doesn't. Dynamic blocks apply the same idea inside a resource. Implicit dependencies from references are almost always preferable to `depends_on`.

**The secrets chain.** A credential travels from Secrets Manager through a task definition into the application's environment without ever appearing in source, in a container image, or in Terraform state output. Each hop is a place it could leak.

**Container image discipline.** Multi-stage builds, a pinned `python:3.12-slim` base, a non-root runtime user, and an image under 200 MB. `EXPOSE` documents intent and does nothing on its own — port publishing is a runtime concern.

**Least-privilege IAM.** The ECS task role is scoped to the specific parameters and bucket it reads. No wildcards, which means the policy has to be written after understanding what the application actually touches.

**SLI-based alerting.** Alarms fire on error rate above 1% for 5 minutes and p95 latency above 500 ms for 10 minutes — symptoms a user would notice — rather than on CPU, which is a cause and often a false alarm.

**Layered scanning.** `trivy` for images and configuration, `checkov` for infrastructure code, `tflint` for Terraform correctness that `validate` cannot catch, and a post-deploy smoke test. These are four different jobs, and none substitutes for another.

**Shared state across replicas.** Any cache local to a process stops being correct the moment a second replica exists. This is the general shape of the problem — the same reasoning applies to sessions, rate-limit counters, and locks.

---

## Project status

Phases are ordered, not scheduled. Each produces an independently shippable repository.

### Phase 1 — ECS Fargate *(in progress)*

| Component | State |
|-----------|-------|
| Terraform state bootstrap — S3, encrypted, public access blocked | ✅ |
| GitHub OIDC provider + CI/CD IAM role | ✅ |
| Networking — VPC, 4 subnets across 2 AZs, routing, flow logs | ✅ |
| CI — `trivy` → `fmt` → `validate` → `plan` → PR diff comment | ✅ |
| Container image — multi-stage, non-root, `python:3.12-slim` | ✅ |
| Local stack — app + PostgreSQL + Valkey, healthchecked | ✅ |
| API — `GET /health` | ✅ |
| API — `/visit`, `/visits`, `/notes`, `/notes/{id}`, `/metrics` | ⬜ stubbed |
| EC2 + cloud-init · budget guardrails · resource tagging | ⬜ |
| ECS Fargate + ALB + ECR + secrets chain · VPC endpoints | ⬜ |
| RDS PostgreSQL + ElastiCache Valkey, wired to the API | ⬜ |
| React dashboard + S3 + CloudFront + WAF · CloudWatch dashboards and alarms | ⬜ |
| Cognito user pool + ALB `authenticate-cognito` | ⬜ |
| `launch.sh` · runbooks · decision record complete | ⬜ |

**Known gaps.** The root module still hardcodes values that belong in variables, CI plans but does not apply, and `bootstrap/` is outside CI's scope — it is run manually and validated by hand. All are scheduled, and listed here rather than hidden.

### Phase 2 — EKS Edition *(planned)*

Same application and Terraform foundation, different compute layer, in a separate repository. Adds managed node groups, IRSA in place of the ECS task role, an ALB Ingress Controller, External Secrets Operator, and Helm packaging. The deliverable is a written comparison of when EKS earns its operational overhead against Fargate — an argument only worth making after building both.

### Phase 3 — Serverless Edition *(planned)*

The same problem solved with Lambda behind API Gateway, SQS with a dead-letter queue for asynchronous work, and EventBridge for scheduling. Introduces RDS Proxy, because Lambda's ephemeral execution exhausts a connection pool that persistent ECS tasks never strained — a real operational difference between the two architectures, not a theoretical one.

---

## Running it locally

The full stack — API, PostgreSQL, and Valkey — runs in containers with no AWS account required:

```bash
docker compose up
```

Requires `DB_USER` and `DB_PASSWORD` in a `.env` file. The API is then on `http://localhost:8000`, and `GET /health` returns `{"status": "ok"}`.

## Repository layout

```
├── bootstrap/          # S3 state bucket — run once, manually
├── main.tf             # root module
├── providers.tf
├── terraform.tf        # versions, providers, S3 backend
├── modules/
│   ├── networking/     # VPC, subnets, routing, flow logs
│   └── github-oidc/    # OIDC provider + CI/CD role
├── app/                # FastAPI service + multi-stage Dockerfile
├── .github/workflows/  # CI
└── docker-compose.yml  # local stack
```

## Code standards

**Terraform** — every module has `variables.tf`, `main.tf`, `outputs.tf`; every variable has a description and type; no hardcoded values outside variables and locals; tags applied through provider `default_tags`; `terraform fmt` before every commit; state never committed.

**Python** — non-root container user, pinned slim base image, typed signatures, no secrets in code, `GET /health` always present and always tested.

**CI** — OIDC only; pull requests produce a plan with a diff comment; merges to `main` apply. Fails fast: `fmt` → `validate` → `tflint` → `trivy` → `checkov` → `plan`.

**Commits** — conventional, scoped: `feat(networking): add VPC flow logs`.
