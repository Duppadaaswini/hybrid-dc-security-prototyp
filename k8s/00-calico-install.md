# After `kind create cluster`, install Calico (needed for NetworkPolicy enforcement — kindnet does NOT enforce policies)

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml

# Wait for it to be ready:
kubectl -n kube-system rollout status daemonset/calico-node
