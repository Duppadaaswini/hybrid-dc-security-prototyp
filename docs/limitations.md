# What's real vs simulated in this prototype (be upfront about this in your report)

**Real / functionally accurate:**
- Kubernetes NetworkPolicy enforcement (Calico) — this is the exact same
  mechanism OpenShift uses under the hood (OpenShift SDN/OVN-Kubernetes
  supports the same NetworkPolicy API).
- AWS API behavior via LocalStack — VPCs, Security Groups, IAM roles/policies
  and S3 are emulated with real AWS semantics (IAM Deny/Allow evaluation is
  functionally equivalent to real AWS for this demo).
- The "AccessDenied" and "connection blocked" results are genuine enforcement
  outcomes, not scripted/faked.

**Simulated / simplified for a laptop prototype:**
- No physical Transit Gateway / Direct Connect link between the kind cluster
  and LocalStack — there's no real network path between them to attack in
  the first place on a single machine. In your report, describe this as
  "logically represented via Terraform route tables and documented policy,"
  and mention that a full build-out would use AWS Transit Gateway + a real
  VPN or Direct Connect circuit to the OpenShift cluster's egress router.
- Keycloak SSO is wired up but not fully chained into AWS IAM Identity
  Center federation (that requires a real AWS account) — describe the
  federation flow in your report/diagram as the target-state design.
- Service mesh mTLS (Istio/Linkerd) between pods is mentioned in the
  architecture but not deployed in this prototype to keep it buildable in a
  reasonable time; call it out as "future work" in your report.

Being explicit about this in your report shows the evaluators you understand
the difference between a prototype and production — which is usually worth
more marks than pretending everything is fully real.
