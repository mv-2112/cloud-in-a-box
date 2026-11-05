#!/usr/bin/env bash
# Write the admin cluster's real kubeconfig, for the platform stage.
#
#   source ../env.sh && ../tools/admin-kubeconfig.sh      # on the Sunbeam host
#   -> ~/.kube/cib-platform.yaml (mode 600)
#
# Why: Magnum's own kubeconfig (`openstack coe cluster config`, or the
# openstack provider's cluster kubeconfig) carries a client certificate
# signed by Magnum's CA. Sunbeam's Magnum builds clusters with Cluster API,
# which gives each cluster its own CA, so the cluster rejects that
# certificate ("the server has asked for the client to provide
# credentials"). Cluster API keeps the working kubeconfig as a secret in
# Sunbeam's management Kubernetes: <stack_id>-kubeconfig in namespace
# magnum-<project_id>. This reads it from there (what `clusterctl get
# kubeconfig` does, without needing clusterctl).
#
# Then it fixes two things in new clusters (see the end of this script):
# control-plane nodes are kept out of LoadBalancer pools, and Canonical
# Kubernetes' MetalLB is switched off (it blanks every LoadBalancer
# Service's address: Sunbeam bug LP#2143394).
#
# Run on the Sunbeam host (it needs `sudo k8s`), with admin credentials
# loaded. Re-run if the cluster is rebuilt; it's safe to re-run any time.
# CIB_KEEP_METALLB=1 skips the MetalLB switch-off.
set -euo pipefail

CLUSTER=${1:-$(terraform -chdir="$(dirname "$0")/../terraform" output -raw admin_cluster_name 2>/dev/null || echo cib-platform)}
OUT=${CIB_KUBECONFIG:-$HOME/.kube/cib-platform.yaml}

info=$(openstack coe cluster show "$CLUSTER" -f json -c stack_id -c project_id -c status)
stack_id=$(jq -r .stack_id <<<"$info")
project_id=$(jq -r .project_id <<<"$info")
status=$(jq -r .status <<<"$info")
[[ $stack_id != null && -n $stack_id ]] || { echo "admin-kubeconfig: $CLUSTER has no stack_id yet (status $status)" >&2; exit 1; }

ns="magnum-$project_id"
secret="$stack_id-kubeconfig"
mkdir -p "$(dirname "$OUT")"
tmp=$(mktemp "$OUT.XXXX")
trap 'rm -f "$tmp"' EXIT
if ! sudo k8s kubectl -n "$ns" get secret "$secret" -o jsonpath='{.data.value}' | base64 -d >"$tmp" || [[ ! -s $tmp ]]; then
  echo "admin-kubeconfig: no secret $ns/$secret in Sunbeam's Kubernetes (is $CLUSTER ready? status $status)" >&2
  exit 1
fi
chmod 600 "$tmp"
mv "$tmp" "$OUT"
trap - EXIT

server=$(awk '/server:/ {print $2; exit}' "$OUT")
echo "admin-kubeconfig: wrote $OUT for $CLUSTER (API $server)"
command -v kubectl >/dev/null || { echo "admin-kubeconfig: kubectl not found; skipping the checks and fixes below" >&2; exit 0; }
k() { kubectl --kubeconfig "$OUT" "$@"; }
k get nodes -o wide || { echo "admin-kubeconfig: written, but kubectl couldn't reach $server" >&2; exit 1; }

# --- Post-create fixes ------------------------------------------------------
# Safety first: these change the cluster's nodes, so only ever act on the
# Magnum cluster's own nodes. Sunbeam's own Kubernetes (on this host) also
# runs Canonical Kubernetes with MetalLB, and there MetalLB serves the
# OpenStack API addresses: both fixes below would break it. Magnum node
# names start with the cluster's (stack) name, and their addresses are on
# the cluster's tenant network, never this host's.
stack_name=$(openstack coe cluster show "$CLUSTER" -f value -c stack_id 2>/dev/null) || stack_name=""
cp_nodes=$(k get nodes -l node-role.kubernetes.io/control-plane -o name)
[[ -n $cp_nodes ]] || { echo "admin-kubeconfig: no control-plane nodes found" >&2; exit 1; }
for n in $cp_nodes; do
  n_ip=$(k get "$n" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
  if [[ ${n#node/} != "$CLUSTER"* && ( -z $stack_name || ${n#node/} != *"${stack_name:0:10}"* ) ]] ||
     ip -o addr 2>/dev/null | grep -qw "inet ${n_ip}"; then
    echo "admin-kubeconfig: refusing: $n ($n_ip) doesn't look like a node of Magnum cluster $CLUSTER" >&2
    exit 1
  fi
done
node=$(head -1 <<<"$cp_nodes")

# 1. Keep control-plane nodes out of LoadBalancer pools. They're also
# workers here, so the cloud controller adds them as members, but their
# security group doesn't open NodePorts: health checks fail and every load
# balancer shows DEGRADED. The standard label makes the controller skip them.
for n in $cp_nodes; do
  k label "$n" node.kubernetes.io/exclude-from-external-load-balancers=true --overwrite >/dev/null &&
    echo "admin-kubeconfig: $n excluded from LoadBalancer pools"
done

# 2. Switch off Canonical Kubernetes' MetalLB (Sunbeam bug LP#2143394).
# Magnum's CAPI clusters run its load-balancer feature (MetalLB, L2 mode)
# with no address pool; MetalLB still claims every LoadBalancer Service and
# clears the address the OpenStack cloud controller (Octavia) sets, so
# Services stay <pending> and Helm waits time out. Idempotent.
if [[ ${CIB_KEEP_METALLB:-} == 1 ]]; then
  echo "admin-kubeconfig: CIB_KEEP_METALLB=1, leaving MetalLB as it is"
elif k -n metallb-system get deploy metallb-controller >/dev/null 2>&1; then
  echo "admin-kubeconfig: disabling Canonical Kubernetes' load-balancer feature (MetalLB) via $node"
  # chroot /host has no /snap/bin on PATH; fall back to the snap's binary.
  cmd='PATH=/snap/bin:/usr/sbin:/usr/bin:/sbin:/bin
       if command -v k8s >/dev/null; then k8s disable load-balancer
       else /snap/k8s/current/bin/k8s disable load-balancer; fi'
  out=$(k debug "$node" --profile=sysadmin --image=ubuntu:24.04 -- chroot /host /bin/sh -c "$cmd" 2>&1)
  pod=$(grep -o 'node-debugger-[a-z0-9.-]*' <<<"$out" | head -1)
  if [[ -n $pod ]]; then
    phase=""
    for _ in $(seq 60); do   # until it finishes, either way (max 5 min)
      phase=$(k get "pod/$pod" -o jsonpath='{.status.phase}' 2>/dev/null) || true
      [[ $phase == Succeeded || $phase == Failed ]] && break
      sleep 5
    done
    k logs "pod/$pod" 2>/dev/null | tail -5 | sed 's/^/  node: /'
    k delete "pod/$pod" --wait=false >/dev/null 2>&1 || true
    if [[ $phase != Succeeded ]]; then
      echo "admin-kubeconfig: 'k8s disable load-balancer' on $node ended '${phase:-unknown}'; MetalLB left as it is" >&2
      exit 1
    fi
  fi
  for _ in $(seq 24); do k -n metallb-system get deploy metallb-controller >/dev/null 2>&1 || break; sleep 5; done
  if k -n metallb-system get deploy metallb-controller >/dev/null 2>&1; then
    echo "admin-kubeconfig: MetalLB's controller is still there; check with: kubectl -n metallb-system get all" >&2
  else
    echo "admin-kubeconfig: MetalLB removed; LoadBalancer Services now belong to Octavia"
  fi
fi
