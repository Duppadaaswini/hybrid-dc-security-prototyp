# Secure Hybrid Datacenter Prototype
### Cisco VIP Project — Zero-Trust Hub-and-Spoke Hybrid DC Architecture

This prototype simulates a hybrid enterprise network with **two applications**
(`app-a`, `app-b`) split across a "private datacenter" (Kubernetes via `kind`,
standing in for OpenShift) and a "public cloud" (LocalStack, standing in for
real AWS — same APIs, runs free on your laptop).

The goal: prove that a compromise of App A **cannot** spread to App B, to the
cloud, or to the core network — because of layered segmentation (Security
Groups + IAM + Kubernetes NetworkPolicies), not just a firewall rule you hope
someone doesn't misconfigure.

---

## 1. Architecture Simulated

| Real-world component | What we run locally |
|---|---|
| OpenShift (private DC, on-prem apps) | `kind` (Kubernetes-in-Docker) cluster, 2 namespaces |
| AWS VPC / Security Groups / IAM | LocalStack + Terraform (real AWS API calls, no AWS bill) |
| Identity Provider (SSO/OIDC) | Keycloak (Docker) |
| Micro-segmentation inside K8s | Kubernetes `NetworkPolicy` (Calico-compatible) |
| Faculty ZTNA remote access | Simple OIDC-protected reverse proxy (nginx + oauth2-proxy) |
| Transit hub between DC and cloud | Simulated conceptually via Terraform route tables (documented, not physically routed — see `docs/limitations.md`) |

---

## 2. Prerequisites (install once)

```bash
# Docker Desktop (or Docker Engine) — required for everything
# kind
go install sigs.k8s.io/kind@latest   # or: brew install kind
# kubectl
brew install kubectl                  # or your OS equivalent
# Terraform
brew install terraform
# awscli (points at LocalStack, not real AWS)
pip install awscli-local
```

## 3. Build order

```bash
# Step 1: spin up the "private datacenter" Kubernetes cluster
kind create cluster --config kind-config.yaml --name private-dc

# Step 2: deploy App A and App B into separate namespaces, then apply
#          zero-trust NetworkPolicies (default-deny + explicit allow)
kubectl apply -f k8s/namespaces.yaml
kubectl apply -f k8s/app-a-deployment.yaml
kubectl apply -f k8s/app-b-deployment.yaml
kubectl apply -f k8s/network-policies.yaml

# Step 3: spin up the "public cloud" — LocalStack (fake AWS)
docker compose up -d localstack keycloak

# Step 4: provision VPCs, Security Groups, and IAM roles with Terraform
cd terraform
terraform init
terraform apply -auto-approve
cd ..

# Step 5: run the attack simulations (see attack-tests/)
bash attack-tests/test-lateral-movement.sh
bash attack-tests/test-iam-privilege-boundary.sh
```

## 4. What to screenshot for your report

1. `kubectl get networkpolicy -A` — shows default-deny is active
2. The **failed** `curl` from App A pod to App B pod (blocked) — proves segmentation
3. `terraform apply` output showing 2 separate VPCs + SGs + IAM roles created
4. The **failed** AWS CLI call when App-A's IAM role tries to touch App-B's S3 bucket (`AccessDenied`)
5. Keycloak login screen + successful SSO into the app (faculty ZTNA flow)
6. A **successful**, authorized request (App A frontend → App A backend) to contrast with the blocked ones

## 5. Project → Report → PPT mapping

- **Diagram**: use `docs/architecture-diagram.md` description (or redraw in draw.io/Lucidchart)
- **Implementation**: this repo
- **Test attack scenarios**: `attack-tests/`
- **Report**: structure it as PS → Requirements → Architecture decision (with alternatives considered) → Implementation → Attack tests + screenshots → Results/limitations → Conclusion
