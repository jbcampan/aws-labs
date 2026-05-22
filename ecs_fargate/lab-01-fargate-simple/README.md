# lab-01-fargate-simple

Deploy a Docker container on ECS Fargate without managing any server.

---

## What This Lab Covers

- **1 VPC** — public and private subnets via the shared `_modules/vpc` module
- **1 ECR repository** — private Docker registry where you push your image
- **1 ECS Cluster** (Fargate) — a logical namespace, no EC2 instances to manage
- **1 Task Definition** — the container blueprint: image, CPU, RAM, port, env vars
- **1 ECS Service** — keeps 1 task running at all times; restarts it if it crashes
- **1 Security Group** — allows inbound traffic on port 5000 only
- The task runs in a public subnet with an automatically assigned public IP

---

## What You Learn

- **ECS terminology** — what Cluster, Task Definition, Task, and Service actually mean in practice
- **Fargate vs EC2 launch type** — why Fargate is the right default today
- **The build → tag → push → deploy workflow** with ECR
- **Task Definition versioning** — every change creates a new numbered revision, enabling rollback
- **ECS Exec** — open an interactive shell inside a running Fargate container for debugging

---

## Architecture

```
Internet
   │
   │ HTTP :5000
   ▼
┌─────────────────────────────────────┐
│           VPC 10.0.0.0/16           │
│                                     │
│  ┌──────────────────────────────┐   │
│  │       Public Subnet          │   │
│  │  ┌────────────────────────┐  │   │
│  │  │  ECS Fargate Task      │  │   │
│  │  │  Flask app :5000       │  │   │
│  │  │  public IP assigned    │  │   │
│  │  └────────────────────────┘  │   │
│  └──────────────────────────────┘   │
└─────────────────────────────────────┘
```

---

## Structure

```
lab-01-fargate-simple/
├── app/
│   ├── app.py              # Flask app — returns hostname + timestamp as JSON
│   ├── requirements.txt
│   └── Dockerfile
├── scripts/
│   ├── 1-infra.sh          # terraform init + apply
│   ├── 2-push.sh           # docker build + tag + push to ECR
│   └── 3-redeploy.sh       # force new ECS deployment + fetch public IP
├── terraform/
│   ├── main.tf             # VPC module call
│   ├── ecr.tf              # ECR repository + lifecycle policy
│   ├── ecs.tf              # Cluster, Task Definition, Service
│   ├── iam.tf              # Task Execution Role + Task Role + ECS Exec policy
│   ├── security_group.tf   # Inbound :5000, outbound all
│   ├── cloudwatch.tf       # Log group /ecs/flask-lab-01
│   ├── variables.tf
│   ├── outputs.tf
│   └── providers.tf
└── README.md
```

---

## Prerequisites

- Terraform >= 1.6
- AWS CLI configured (`aws configure`)
- Docker Desktop installed and running
- Scripts must be run from **WSL or Git Bash** (not PowerShell)

---

## Full Lab Walkthrough

### Step 1 — Deploy the infrastructure

```bash
bash scripts/1-infra.sh
```

Terraform shows the plan (~17 resources). Read it, then type `yes`.

**Console checks:**
- **ECR** → your repository `flask-lab-01-app` is present
- **ECS** → Clusters → `flask-lab-01` → Services → `flask-lab-01-service` exists, `0/1 running` (normal — no image yet)
- **CloudWatch** → Log groups → `/ecs/flask-lab-01` exists

---

### Step 2 — Build and push the image

```bash
bash scripts/2-push.sh
```

**Console check:**
- **ECR** → your repository → Images tab → one image tagged `latest` is visible

---

### Step 3 — Deploy and get the URL

```bash
bash scripts/3-redeploy.sh
```

The script waits for the service to stabilise, then prints the task's public IP.

**Console checks:**
- **ECS** → Clusters → `flask-lab-01` → Tasks tab → 1 task with status `RUNNING`
- Click the task → Logs tab → Gunicorn startup logs are visible

---

### Step 4 — Test the application

```bash
curl http://<PUBLIC_IP>:5000/
# {
#   "hostname": "ip-10-0-1-xxx.eu-west-3.compute.internal",
#   "message": "Hello from ECS Fargate!",
#   "timestamp": "2026-01-15T10:30:00+00:00"
# }

curl http://<PUBLIC_IP>:5000/health
# {"status": "ok"}
```

Note the `hostname` — it identifies the running container. It will change at every new deployment, and will be used in lab-02 to visualise load balancing across multiple tasks.

---

### Step 5 — ECS Exec (debug shell)

ECS Exec is the Fargate equivalent of `docker exec` — it opens an interactive shell inside a running container.

> **Windows users:** ECS Exec does not work in Git Bash. Use WSL (Ubuntu).
> Install the [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) first.

```bash
TASK_ARN=$(aws ecs list-tasks \
  --cluster flask-lab-01 \
  --service-name flask-lab-01-service \
  --region eu-west-3 \
  --query 'taskArns[0]' --output text)

aws ecs execute-command \
  --cluster flask-lab-01 \
  --task $TASK_ARN \
  --container app \
  --command "/bin/bash" \
  --interactive \
  --region eu-west-3
```

Once inside:

```bash
env | grep -E "(ENVIRONMENT|PORT|HOSTNAME)"  # env vars injected by ECS
curl localhost:5000/                          # call the app from inside
ps aux                                        # gunicorn + workers
exit
```

---

### Step 6 — Test service resilience

This demonstrates one of ECS Service's core behaviours: it always maintains `desired_count` tasks.

In the AWS console: **ECS → Tasks → select the running task → Stop**

Observe: within seconds, ECS automatically starts a new task. The new task will have a different IP and a different `hostname`.

---

### Step 7 — Explore Task Definition revisions

```bash
# List all revisions created so far
aws ecs list-task-definitions \
  --family-prefix flask-lab-01 \
  --region eu-west-3

# Roll back to a specific revision
aws ecs update-service \
  --cluster flask-lab-01 \
  --service flask-lab-01-service \
  --task-definition flask-lab-01:1 \
  --region eu-west-3
```

Every `terraform apply` that modifies the Task Definition creates a new numbered revision (`flask-lab-01:1`, `flask-lab-01:2`...). This is what makes rollbacks possible without redeploying.

---

### Step 8 — Follow logs in real time

```bash
aws logs tail /ecs/flask-lab-01 --follow --region eu-west-3
```

Each `curl` on the app generates a Gunicorn access log line. You can also browse them in the console: **CloudWatch → Log groups → `/ecs/flask-lab-01`**.

---

### Step 9 — Cleanup

Empty ECR first (Terraform cannot delete a non-empty repository):

```bash
aws ecr batch-delete-image \
  --repository-name flask-lab-01-app \
  --image-ids "$(aws ecr list-images \
    --repository-name flask-lab-01-app \
    --region eu-west-3 \
    --query 'imageIds[*]' \
    --output json)" \
  --region eu-west-3

cd terraform && terraform destroy
```

**Console checks after destroy:**
- ECS → cluster `flask-lab-01` is gone
- ECR → repository `flask-lab-01-app` is gone
- CloudWatch → log group `/ecs/flask-lab-01` is gone
- VPC → `flask-lab-01-vpc` is gone

---

## Verification Checklist

| Where | What to check |
|---|---|
| ECR → Images | Image tagged `latest` is present after `2-push.sh` |
| ECS → Tasks | 1 task in `RUNNING` state |
| ECS → Task → Logs | Gunicorn startup lines visible |
| curl `/` | Returns `hostname` + `timestamp` JSON |
| curl `/health` | Returns `{"status": "ok"}` |
| After stopping the task | ECS restarts a new one automatically |
| After destroy | Cluster, ECR, log group, VPC all gone |

---

## Cost

| Resource | Cost |
|---|---|
| Fargate task (256 CPU, 512 MB) | ~$0.01/hour |
| ECR storage | ~$0.10/GB/month |
| CloudWatch Logs | ~$0.50/GB ingested |
| **Total for a 2-hour lab** | **~$0.02** |

> Always destroy after the lab.

---

## Key Concepts

| Term | Meaning |
|---|---|
| **Cluster** | Logical namespace — groups services together, no servers |
| **Task Definition** | Versioned blueprint: image, CPU, RAM, ports, env vars |
| **Task** | A running instance of a Task Definition |
| **Service** | Keeps N tasks alive; manages rolling updates |
| **Fargate** | Serverless compute — no EC2 instances to manage |
| **ECR** | AWS private Docker registry |
| **Task Execution Role** | IAM role used by ECS agent (pull image, send logs) |
| **Task Role** | IAM role used by your application (S3, DynamoDB...) |
| **awsvpc** | Fargate network mode — each task gets its own ENI |
| **ECS Exec** | Interactive shell inside a running Fargate container |