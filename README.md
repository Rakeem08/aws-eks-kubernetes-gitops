# Tech Challenge 2

Application Deployment with Docker, Terraform, Amazon EKS, Helm, Jenkins, GitHub Actions, and Argo CD.

## Live Application

[Open the deployed Hello World application](http://k8s-techchal-techchal-ce433c8d4f-1761637325.us-east-1.elb.amazonaws.com)

## Project Objective

This project demonstrates how to containerize a Node.js web application, create AWS infrastructure using Terraform, deploy the application to Amazon EKS with Helm, and automate deployments with Jenkins.

A separate `gitops` branch demonstrates the GitOps alternative using GitHub Actions and Argo CD.

## Architecture

![AWS EKS delivery, application runtime and operations](docs/images/eks-architecture.svg)

[Open the full-size architecture graphic](docs/images/eks-architecture.svg)

This diagram shows the `main` branch delivery path: Jenkins builds and health-tests the image, pushes it to ECR, and deploys a versioned tag with Helm. Ingress is reconciled by the AWS Load Balancer Controller; the ALB uses IP targets to reach application pods. The ClusterIP Service selects the pods but is not a separate ALB traffic hop in this configuration. Dotted arrows show deployment, image, or control-plane flow.

## Technologies

- Node.js and Express
- Docker
- Terraform
- Amazon ECR
- Amazon EKS
- Kubernetes
- Helm
- AWS Load Balancer Controller
- Kubernetes Metrics Server
- Kubernetes Cluster Autoscaler
- Jenkins
- GitHub Actions
- Argo CD

## Repository Structure

```text
.
├── app/
│   ├── Dockerfile
│   ├── package.json
│   ├── package-lock.json
│   └── server.js
├── helm/
│   └── tech-challenge-2/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── service.yaml
│           ├── ingress.yaml
│           └── hpa.yaml
├── terraform/
│   ├── ecr.tf
│   ├── eks.tf
│   ├── iam.tf
│   ├── jenkins.tf
│   ├── network.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── versions.tf
├── Jenkinsfile
└── README.md
```

## Web Application

The application is a small Express web server.

Available endpoints:

| Endpoint | Purpose |
|---|---|
| `/` | Returns `Hello, World!` |
| `/health` | Returns `OK` for container and Kubernetes health checks |

The server listens on port `3000` and binds to `0.0.0.0`, allowing it to run inside a Docker container.

## Prerequisites

Install and configure:

- Git
- Node.js and npm
- Docker Desktop
- Terraform 1.5.7 or newer
- AWS CLI version 2
- kubectl
- Helm
- An AWS account with appropriate permissions
- An EC2 key pair in `us-east-1`

Confirm the tools:

```powershell
git --version
node --version
npm --version
docker --version
terraform version
aws --version
kubectl version --client
helm version
```

Configure AWS CLI:

```powershell
aws configure
```

Confirm the AWS identity:

```powershell
aws sts get-caller-identity
```

## Clone the Repository

```powershell
git clone https://github.com/Rakeem08/cloud-engineer-tech-challenge-2.git
cd cloud-engineer-tech-challenge-2
```

## Run the Application Locally

Move into the application directory:

```powershell
cd app
```

Install dependencies:

```powershell
npm.cmd ci
```

Start the application:

```powershell
npm.cmd start
```

Test it:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:3000
Invoke-WebRequest -UseBasicParsing http://localhost:3000/health
```

## Run with Docker

Build the image from the repository root:

```powershell
docker build -t tech-challenge-2-app:local .\app
```

Start the container:

```powershell
docker run --detach `
  --name tech-challenge-2-local `
  --publish 3000:3000 `
  tech-challenge-2-app:local
```

Test the container:

```powershell
Invoke-WebRequest -UseBasicParsing http://localhost:3000
Invoke-WebRequest -UseBasicParsing http://localhost:3000/health
```

Remove the test container:

```powershell
docker rm --force tech-challenge-2-local
```

## Terraform Infrastructure

Terraform provisions:

- A VPC across two Availability Zones
- Public and private subnets
- Internet Gateway
- NAT Gateway
- Amazon ECR repository
- Amazon EKS cluster
- EKS managed node group
- Jenkins EC2 server
- Security groups
- IAM roles and policies
- EKS Pod Identity associations

### EKS Configuration

The managed node group uses:

- Instance type: `t3.small`
- Minimum nodes: `1`
- Desired nodes: `1`
- Maximum nodes: `4`
- Amazon Linux 2023
- 30 GB encrypted storage
- Node repair enabled

The nodes run in private subnets. The EKS API supports private and public access.

### Terraform Variables

Create `terraform/terraform.tfvars`:

```hcl
jenkins_key_name     = "YOUR_AWS_KEY_PAIR_NAME"
jenkins_allowed_cidr = "YOUR_PUBLIC_IP/32"
```

Do not commit this file. It is excluded by `.gitignore`.

### Deploy the Infrastructure

Initialize Terraform:

```powershell
terraform -chdir=terraform init
```

Format and validate:

```powershell
terraform fmt
terraform -chdir=terraform validate
```

Create a saved plan:

```powershell
terraform -chdir=terraform plan -out=tfplan
```

Review the plan carefully, then apply it:

```powershell
terraform -chdir=terraform apply tfplan
```

Configure kubectl:

```powershell
aws eks update-kubeconfig `
  --region us-east-1 `
  --name tech-challenge-2-eks
```

Confirm the node:

```powershell
kubectl get nodes
```

## Amazon ECR

The ECR repository stores the Docker images used by EKS.

Retrieve the repository URL:

```powershell
$ecrUrl = terraform -chdir=terraform output -raw ecr_repository_url
```

Retrieve the registry:

```powershell
$registry = $ecrUrl.Split("/")[0]
```

Authenticate Docker:

```powershell
$ecrPassword = aws ecr get-login-password --region us-east-1
docker login --username AWS --password $ecrPassword $registry
Remove-Variable ecrPassword
```

Build and push:

```powershell
docker build -t tech-challenge-2-app:latest .\app
docker tag tech-challenge-2-app:latest "${ecrUrl}:latest"
docker push "${ecrUrl}:latest"
```

## Kubernetes and Helm

The Helm chart creates:

- Kubernetes Deployment
- ClusterIP Service
- ALB Ingress
- Horizontal Pod Autoscaler
- Readiness and liveness probes
- CPU and memory resource requests
- Non-root container security settings
- Pod topology spread rules

Validate the Helm chart:

```powershell
helm lint .\helm\tech-challenge-2
```

Deploy the chart:

```powershell
$ecrUrl = terraform -chdir=terraform output -raw ecr_repository_url

helm upgrade --install tech-challenge-2 `
  .\helm\tech-challenge-2 `
  --namespace tech-challenge-2 `
  --create-namespace `
  --set image.repository=$ecrUrl `
  --set image.tag=latest `
  --wait `
  --timeout=10m
```

Verify the deployment:

```powershell
kubectl get pods -n tech-challenge-2
kubectl get deployment -n tech-challenge-2
kubectl get service -n tech-challenge-2
kubectl get ingress -n tech-challenge-2
kubectl get hpa -n tech-challenge-2
```

## Autoscaling

### Pod Autoscaling

The Horizontal Pod Autoscaler uses:

- Minimum pods: `1`
- Maximum pods: `12`
- CPU target: `50%`
- Memory target: `50%`

Twelve pods allow approximately three pods per node when the cluster reaches four nodes. Topology spread rules help Kubernetes distribute pods across available nodes.

### Node Autoscaling

The Cluster Autoscaler changes the number of EC2 worker nodes according to pod demand:

- Minimum nodes: `1`
- Maximum nodes: `4`

The Kubernetes Metrics Server provides CPU and memory information to the HPA.

## Application Load Balancer

The AWS Load Balancer Controller creates an internet-facing ALB from the Kubernetes Ingress.

Retrieve the public address:

```powershell
$albAddress = kubectl get ingress tech-challenge-2 `
  -n tech-challenge-2 `
  -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"

"http://$albAddress"
```

## Jenkins Server

Terraform creates a Jenkins server on an Amazon Linux 2023 EC2 instance.

The startup script installs:

- Jenkins LTS
- Amazon Corretto Java 21
- Docker
- AWS CLI
- kubectl
- Helm
- Git

Ports `22` and `8080` are restricted to the administrator’s `/32` public IP address.

Retrieve the Jenkins public IP:

```powershell
$jenkinsIp = aws ec2 describe-instances `
  --region us-east-1 `
  --filters `
    "Name=tag:Name,Values=tech-challenge-2-jenkins" `
    "Name=instance-state-name,Values=running" `
  --query "Reservations[0].Instances[0].PublicIpAddress" `
  --output text

"http://${jenkinsIp}:8080"
```

Retrieve the initial unlock password from the server:

```powershell
ssh -i "PATH_TO_KEY_FILE" ec2-user@$jenkinsIp
```

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Do not commit passwords, private keys, or GitHub tokens.

## Jenkins GitHub Credential

The private GitHub repository is accessed with a fine-grained personal access token.

The token should have:

- Access to only `cloud-engineer-tech-challenge-2`
- Repository Contents permission set to read-only
- An expiration date

Store it in Jenkins as:

- Kind: Username with password
- Username: `Rakeem08`
- ID: `github-tech-challenge-2`
- Password: GitHub fine-grained token

## Jenkins Pipeline

The root `Jenkinsfile` performs:

1. Repository checkout
2. AWS and image preparation
3. Docker image build
4. Container health test
5. ECR authentication
6. Versioned image push
7. `latest` image push
8. Helm deployment to EKS
9. Kubernetes rollout verification
10. Workspace cleanup

Each build uses the Jenkins build number as the Docker image tag.

The pipeline polls the `main` branch every five minutes for changes.

### Create the Jenkins Job

Create a Jenkins Pipeline job with:

- Name: `tech-challenge-2-pipeline`
- Definition: Pipeline script from SCM
- SCM: Git
- Repository:

```text
https://github.com/Rakeem08/cloud-engineer-tech-challenge-2.git
```

- Credentials: `github-tech-challenge-2`
- Branch: `*/main`
- Script path: `Jenkinsfile`

Run **Build Now** and confirm:

```text
Finished: SUCCESS
```

## Security Features

- EKS worker nodes run in private subnets.
- Jenkins ports are restricted to one administrator IP.
- Jenkins uses an EC2 IAM role instead of stored AWS access keys.
- Jenkins receives namespace-scoped EKS access.
- ECR permissions are limited to the application repository.
- Kubernetes containers run as a non-root numeric user.
- Linux capabilities are dropped from the application container.
- Health probes monitor the application.
- Terraform variable files, state files, plans, private keys, and secrets are excluded from Git.

## Problems Solved

### Non-root Container Error

Kubernetes initially rejected the container because the Docker image used the named user `node`. Kubernetes could not verify that the named user was non-root.

The deployment was corrected with numeric values:

```yaml
runAsNonRoot: true
runAsUser: 1000
runAsGroup: 1000
fsGroup: 1000
```

### Jenkins Installation Error

Amazon Linux already included `curl-minimal`. Installing the regular `curl` package caused a package conflict and stopped the startup script.

The duplicate `curl` installation was removed from `jenkins.tf`.

### Jenkins-to-EKS Timeout

Jenkins could authenticate with AWS but initially could not reach the private EKS API endpoint.

A security group rule was added to allow the Jenkins security group to reach the EKS API on TCP port `443`.

## GitOps Alternative

The required GitOps implementation is maintained in the separate `gitops` branch.

It uses:

- GitHub Actions to build and push Docker images to ECR
- Argo CD to monitor the Helm chart
- Argo CD to synchronize the desired Git configuration with EKS

## Cleanup

AWS resources generate charges while they are running.

Remove the application first:

```powershell
helm uninstall tech-challenge-2 -n tech-challenge-2
```

Wait for the ALB to be deleted, then remove the supporting Helm releases:

```powershell
helm uninstall aws-load-balancer-controller -n kube-system
helm uninstall cluster-autoscaler -n kube-system
helm uninstall metrics-server -n kube-system
```
## GitOps Alternative: GitHub Actions and Argo CD

The `gitops` branch contains an alternative CI/CD process using GitHub Actions and Argo CD.

### How the GitOps Pipeline Works

1. A developer pushes an application change to the `gitops` branch.
2. GitHub Actions tests and builds the Docker image.
3. GitHub Actions pushes the image to Amazon ECR using the Git commit SHA as the image tag.
4. GitHub Actions updates the image tag in `helm/tech-challenge-2/values.yaml`.
5. Argo CD detects the Helm change and automatically synchronizes it with EKS.
6. Kubernetes deploys the new image and performs a rolling update.

### GitOps Architecture

![GitHub Actions build and image publication, versioned Helm values, and Argo CD reconciliation to EKS](docs/images/gitops-architecture.svg)

[Open the full-size GitOps graphic](docs/images/gitops-architecture.svg)

The `gitops` branch contains the alternative delivery implementation. GitHub Actions uses AWS OIDC, tests the container, publishes an image tagged with the commit SHA, and commits the updated Helm image values. Argo CD reads those values from Git and synchronizes the Helm chart to EKS. Automated prune and self-heal are configured. This diagram describes repository configuration rather than asserting a currently running deployment.

### Destroy the Terraform infrastructure

```powershell
terraform -chdir=terraform plan -destroy -out=destroy.tfplan
terraform -chdir=terraform apply destroy.tfplan
```

## Submission Checklist

- [x] Private GitHub repository
- [x] Node.js Hello World application
- [x] Dockerfile
- [x] Amazon ECR repository
- [x] Terraform-managed EKS cluster
- [x] Auto-scaling managed node group
- [x] Kubernetes HPA using CPU and memory
- [x] AWS Application Load Balancer
- [x] Helm deployment
- [x] Jenkins server
- [x] Jenkins CI/CD pipeline
- [x] Public application URL
- [ ] GitOps branch
- [ ] GitHub Actions workflow
- [ ] Argo CD deployment
- [ ] Repository shared with mentor