# AWS EKS — GitHub Actions and Argo CD Alternative

This `gitops` branch contains the alternative delivery workflow for the public [aws-eks-kubernetes-gitops repository](https://github.com/Rakeem08/aws-eks-kubernetes-gitops). The [main README](https://github.com/Rakeem08/aws-eks-kubernetes-gitops/blob/main/README.md) documents shared infrastructure, local application commands, and the main Jenkins workflow.

## Delivery ownership

| Branch | Delivery path | Image deployed |
|---|---|---|
| `main` | Jenkins builds, checks container health, publishes to ECR, and deploys directly with Helm. | Jenkins build-number tag |
| `gitops` | GitHub Actions builds, checks container health, publishes to ECR, and commits Helm values; Argo CD reconciles the chart. | Git commit SHA |

Use one deployment owner for the application release. Disable the Jenkins job before giving Argo CD ownership of the same release and namespace.

The existing `tech-challenge-2` chart, namespace, release, ECR repository, and AWS resource names remain implementation identifiers. The GitHub repository name has changed; these resources have not been renamed.

## Architecture

![GitHub Actions image publication, Helm values, and Argo CD reconciliation to EKS](docs/images/gitops-architecture.svg)

[Open the full-size graphic](docs/images/gitops-architecture.svg)

The diagram describes configured behavior. It does not establish a currently running or successfully synchronized deployment.

## Implementation

| File | Role |
|---|---|
| [`.github/workflows/gitops-ci.yml`](.github/workflows/gitops-ci.yml) | Image build, container health check, ECR publication, and Helm-values commit |
| [`terraform/github-actions.tf`](terraform/github-actions.tf) | GitHub OIDC provider, branch-scoped IAM trust, and ECR permissions |
| [`argocd/application.yaml`](argocd/application.yaml) | Argo CD Application tracking this branch's Helm chart |
| [`helm/tech-challenge-2/values.yaml`](helm/tech-challenge-2/values.yaml) | Desired application image, resources, ingress, and HPA configuration |

1. A push to `gitops` affecting `app/**` or the workflow file triggers CI. Manual dispatch is also configured; select `gitops` when using it.
2. Actions assumes the role named by the repository variable `AWS_ROLE_ARN` using temporary OIDC credentials.
3. It builds the Docker image and checks `http://localhost:3000/health`.
4. It publishes commit-SHA and `latest` image tags to ECR.
5. It updates `image.repository` and `image.tag` in the Helm values, then pushes that change to `gitops`.
6. An installed Argo CD instance with this Application applied reconciles the chart into EKS. Automated prune, self-heal, and namespace creation are configured.

The workflow performs a container health check, not a comprehensive application test suite. Actions does not run Helm against EKS.

## Setup

Clone the current public repository and select this branch:

```powershell
git clone --branch gitops https://github.com/Rakeem08/aws-eks-kubernetes-gitops.git
cd aws-eks-kubernetes-gitops
```

1. Follow the [shared infrastructure prerequisites](https://github.com/Rakeem08/aws-eks-kubernetes-gitops/blob/main/README.md#terraform-infrastructure). Use this branch's Terraform configuration to include the Actions OIDC role. For an existing environment, retain its Terraform state; review a plan before applying changes. The shared Terraform configuration still includes a Jenkins host even when this delivery path does not use it.
2. Install the [supporting controllers](https://github.com/Rakeem08/aws-eks-kubernetes-gitops/blob/main/README.md#supporting-controllers-must-be-installed-separately) separately. Terraform defines controller IAM access but does not install the AWS Load Balancer Controller, Cluster Autoscaler, or Metrics Server.
3. Set the repository variable `AWS_ROLE_ARN` to the `github_actions_role_arn` Terraform output. Ensure workflow permissions and branch rules allow the values commit.
4. Install Argo CD separately and give it access to the destination cluster.
5. Disable competing Jenkins/manual deployment automation. With kubectl connected to the intended cluster, apply the Application:

```powershell
kubectl apply -f .\argocd\application.yaml
```

The Application now uses the current public repository URL and tracks `gitops`. Its OIDC role trust uses this repository's immutable identity:

```text
repo:Rakeem08@300660116/aws-eks-kubernetes-gitops@1338752891:ref:refs/heads/gitops
```

The numeric IDs bind trust to this owner and repository. For a fork or a custom OIDC subject template, review and update the trust to match the actual issued subject. See [GitHub's immutable subject documentation](https://docs.github.com/en/actions/reference/security/oidc#immutable-subject-claims).

## Verification

After applying infrastructure changes and configuring the environment:

- Inspect the GitHub Actions run for successful AWS authentication, container health check, ECR push, and values commit.
- Confirm the committed image tag matches the application commit SHA.
- Verify Argo CD reports the intended revision as `Synced` and the Application as `Healthy`.
- Check pods, rollout status, ingress, and metrics:

```powershell
kubectl get application tech-challenge-2 -n argocd
kubectl rollout status deployment/tech-challenge-2 -n tech-challenge-2 --timeout=5m
kubectl get pods,service,ingress,hpa -n tech-challenge-2
kubectl top pods -n tech-challenge-2
```

The historical lab URL is not evidence of current availability. No new end-to-end deployment or load-test result is claimed by this README.

## Cleanup

Disable Argo CD reconciliation before deleting workloads so self-heal does not recreate them. Review Application deletion behavior, remove application workloads, and wait for ALB deletion before removing supporting controllers. Review the [shared cleanup instructions](https://github.com/Rakeem08/aws-eks-kubernetes-gitops/blob/main/README.md#cleanup), then review a Terraform destroy plan when the environment is no longer needed.

## Implementation status

Checked items indicate files/configuration present.

- [x] Public repository and dedicated `gitops` branch
- [x] GitHub Actions image build, health check, publication, and Helm-values update workflow
- [x] Argo CD Application with automated prune and self-heal
- [x] Current repository URL and exact owner/repository IDs in OIDC trust
- [ ] Apply the updated trust and configure the repository/environment
- [ ] Verify CI, Argo CD synchronization, and application health end to end
