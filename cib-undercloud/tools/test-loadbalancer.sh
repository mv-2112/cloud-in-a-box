#!/usr/bin/env bash
# Test Kubernetes LoadBalancer Services on a Magnum cluster, end to end, and
# keep the evidence.
#
#   source ../env.sh
#   ./test-loadbalancer.sh                       # admin cluster (~/.kube/cib-platform.yaml)
#   ./test-loadbalancer.sh --ab                  # + MetalLB A/B: sample with its controller stopped, then running
#   ./test-loadbalancer.sh --kubeconfig F --cluster NAME --keep
#
# It deploys a small echo server (2 replicas) behind a LoadBalancer Service
# in namespace cib-lbtest and checks, in order:
#   1. Octavia builds the load balancer (provider, status, VIP, members)
#   2. the Service gets an external address, and keeps it (sampled every 2 s)
#   3. the address answers from here (outside the cluster), and the VIP and a
#      NodePort answer from inside it
#   4. (--ab) whether MetalLB's controller is what clears the address
# then removes everything and checks the Octavia load balancer is gone.
#
# Run where `openstack` (admin credentials, env.sh) and `kubectl` work and
# the external network is reachable, e.g. the Sunbeam host. Evidence goes to
# lbtest-<date>/ (report.md + raw outputs); attach that to a bug report.
set -uo pipefail

KUBECONFIG_FILE=~/.kube/cib-platform.yaml
CLUSTER=cib-platform
AB=false
KEEP=false
SAMPLE_SECS=60
LB_TIMEOUT=900          # amphora: a VM has to boot
NS=cib-lbtest
IMAGE=registry.k8s.io/e2e-test-images/agnhost:2.53

while (($#)); do
  case $1 in
    --kubeconfig) KUBECONFIG_FILE=$2; shift ;;
    --cluster) CLUSTER=$2; shift ;;
    --ab) AB=true ;;
    --keep) KEEP=true ;;
    --sample-secs) SAMPLE_SECS=$2; shift ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
  shift
done

OUT=lbtest-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
REPORT=$OUT/report.md
k() { kubectl --kubeconfig "$KUBECONFIG_FILE" "$@"; }
log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$OUT/run.log"; }
declare -A VERDICT
verdict() { VERDICT[$1]="$2|$3"; log "$1: $2 ${3:+($3)}"; }

for c in kubectl openstack jq curl; do
  command -v $c >/dev/null || { echo "needs $c" >&2; exit 2; }
done
k get nodes >/dev/null || { echo "kubectl can't reach the cluster with $KUBECONFIG_FILE" >&2; exit 2; }
openstack token issue >/dev/null || { echo "openstack can't authenticate: source env.sh" >&2; exit 2; }

METALLB_SCALED=false
cleanup() {
  if $METALLB_SCALED; then
    log "restoring MetalLB's controller"
    k -n metallb-system scale deploy metallb-controller --replicas=1 >/dev/null
  fi
}
trap cleanup EXIT

# ------------------------------------------------------------- 0. context --
log "collecting environment"
{
  echo "## cluster";       openstack coe cluster show "$CLUSTER" -f json 2>&1
  tmpl=$(openstack coe cluster show "$CLUSTER" -f value -c cluster_template_id 2>/dev/null)
  echo "## template";      openstack coe cluster template show "$tmpl" -f json 2>&1
  echo "## octavia providers"; openstack loadbalancer provider list -f json 2>&1
  echo "## kubernetes";    k version -o json 2>&1
  echo "## nodes";         k get nodes -o wide 2>&1
  echo "## metallb";       k -n metallb-system get deploy,ds -o wide 2>&1
  k get ipaddresspools,l2advertisements,bgpadvertisements -A 2>&1
  k -n metallb-system get deploy metallb-controller -o jsonpath='{.spec.template.spec.containers[0].args}{"\n"}' 2>&1
  echo "## cloud controller"; k -n openstack-system get ds,deploy -o wide 2>&1
  if command -v snap >/dev/null; then echo "## snaps"; snap list openstack openstack-hypervisor 2>&1; fi
  if command -v juju >/dev/null; then
    echo "## charms"
    juju status -m openstack --format json 2>/dev/null |
      jq -r '.applications | to_entries[] | select(.key|test("magnum|octavia|neutron")) | "\(.key) \(."charm-channel") rev \(."charm-rev")"'
  fi
} >"$OUT/environment.txt" 2>&1
# The CLI returns labels as structured data or as a Python-style string,
# depending on version; read the provider from either.
provider_label=$(openstack coe cluster template show "$tmpl" -f json 2>/dev/null | jq -r '
  .labels | if type == "object" then (.octavia_provider // "?")
            else ((tostring | capture("octavia_provider[^a-z]+(?<p>[a-z]+)").p) // "?") end' 2>/dev/null)
provider_label=${provider_label:-?}
metallb=$(k -n metallb-system get deploy metallb-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
log "cluster $CLUSTER, template octavia_provider=$provider_label, MetalLB controller ready=${metallb:-absent}"

# ----------------------------------------------------------- 1. workload --
log "deploying echo server + LoadBalancer Service in $NS"
k create namespace "$NS" --dry-run=client -o yaml | k apply -f - >/dev/null
k -n "$NS" apply -f - >/dev/null <<EOF
apiVersion: apps/v1
kind: Deployment
metadata: {name: echo}
spec:
  replicas: 2
  selector: {matchLabels: {app: echo}}
  template:
    metadata: {labels: {app: echo}}
    spec:
      containers:
        - name: echo
          image: $IMAGE
          args: ["netexec", "--http-port=8080"]
          ports: [{containerPort: 8080}]
          readinessProbe: {httpGet: {path: /healthz, port: 8080}}
---
apiVersion: v1
kind: Service
metadata: {name: echo}
spec:
  type: LoadBalancer
  selector: {app: echo}
  ports: [{name: http, port: 80, targetPort: 8080}]
EOF
k -n "$NS" rollout status deploy/echo --timeout=180s >>"$OUT/run.log" 2>&1 &&
  verdict pods PASS "2 echo replicas ready" || verdict pods FAIL "echo pods not ready"

# ------------------------------------------------------------ 2. octavia --
log "waiting for the cloud controller to create the Octavia load balancer"
lb_id=""
for _ in $(seq 60); do
  lb_id=$(k -n "$NS" get svc echo -o jsonpath='{.metadata.annotations.loadbalancer\.openstack\.org/load-balancer-id}')
  [[ -n $lb_id ]] && break; sleep 5
done
if [[ -z $lb_id ]]; then
  verdict octavia FAIL "no load balancer after 5 min"
else
  deadline=$((SECONDS + LB_TIMEOUT))
  while :; do
    openstack loadbalancer show "$lb_id" -f json >"$OUT/lb.json" 2>&1
    ps=$(jq -r .provisioning_status "$OUT/lb.json" 2>/dev/null)
    [[ $ps == ACTIVE || $ps == ERROR || $SECONDS -ge $deadline ]] && break
    sleep 10
  done
  start=$(jq -r .created_at "$OUT/lb.json"); upd=$(jq -r .updated_at "$OUT/lb.json")
  read -r prov os vip <<<"$(jq -r '"\(.provider) \(.operating_status) \(.vip_address)"' "$OUT/lb.json")"
  openstack loadbalancer status show "$lb_id" >"$OUT/lb-status.json" 2>&1
  # Member health (amphora runs health monitors; OVN shows NO_MONITOR).
  # Map each failing member's address back to its node.
  bad=$(jq -r '[.loadbalancer.listeners[].pools[].members[] | select(.operating_status != "ONLINE" and .operating_status != "NO_MONITOR")
               | .address] | unique | .[]' "$OUT/lb-status.json" 2>/dev/null)
  total=$(jq '[.loadbalancer.listeners[].pools[].members[].address] | unique | length' "$OUT/lb-status.json" 2>/dev/null)
  if [[ -z $bad ]]; then
    verdict members PASS "all ${total:-?} member nodes healthy"
  else
    names=""
    for a in $bad; do
      names+="$(k get nodes -o json | jq -r --arg a "$a" '.items[] | select(any(.status.addresses[]; .address == $a)) | .metadata.name') ($a) "
    done
    verdict members FAIL "unhealthy: $names; a control-plane node here usually means it isn't excluded from LB pools (admin-kubeconfig.sh)"
  fi
  [[ $ps == ACTIVE ]] && verdict octavia PASS "provider $prov, $ps/$os, VIP $vip, created $start, ready $upd" \
                      || verdict octavia FAIL "provider $prov, $ps/$os after ${LB_TIMEOUT}s"
fi
fip=$(k -n "$NS" get svc echo -o jsonpath='{.metadata.annotations.loadbalancer\.openstack\.org/load-balancer-address}')
[[ -z $fip && -n ${vip:-} ]] && fip=$(openstack floating ip list --fixed-ip-address "$vip" -f value -c "Floating IP Address" | head -1)
[[ -n $fip ]] && verdict floating_ip PASS "$fip" || verdict floating_ip FAIL "none assigned"

# ------------------------------------------------- 3. status stability --
# Service .status.loadBalancer.ingress, every 2 s. "set" = has an address.
sample() {   # sample <label> <seconds>
  local label=$1 secs=$2 set=0 empty=0 flips=0 last="" ip
  local file="$OUT/status-$label.log"
  for _ in $(seq $((secs / 2))); do
    ip=$(k -n "$NS" get svc echo -o jsonpath='{.status.loadBalancer.ingress[*].ip}' 2>/dev/null)
    echo "$(date +%H:%M:%S) ${ip:-<empty>}" >>"$file"
    if [[ -n $ip ]]; then ((set++)); else ((empty++)); fi
    [[ -n $last && $last != "${ip:-empty}" ]] && ((flips++))
    last=${ip:-empty}; sleep 2
  done
  echo "$set $empty $flips"
}
nudge() { k -n "$NS" annotate svc echo cib/resync="$(date +%s%N)" --overwrite >/dev/null; }

log "sampling the Service's external address for ${SAMPLE_SECS}s"
nudge
read -r s e f <<<"$(sample baseline "$SAMPLE_SECS")"
if ((e == 0)); then verdict status_stable PASS "address set in all $s samples"
elif ((s == 0)); then verdict status_stable FAIL "address never set ($e samples empty)"
else verdict status_stable FAIL "address set $s / empty $e samples, $f changes"; fi
k -n "$NS" get svc echo -o yaml --show-managed-fields >"$OUT/service-managedfields.yaml" 2>&1

# -------------------------------------------------------- 4. reachability --
if [[ -n $fip ]]; then
  log "curling http://$fip/hostname 20 times from $(hostname)"
  for _ in $(seq 20); do
    curl -s --max-time 4 "http://$fip/hostname" || printf 'TIMEOUT'; echo
  done >"$OUT/external-curl.log" 2>&1
  ok=$(grep -cv '^TIMEOUT$' "$OUT/external-curl.log"); pods=$(grep -v '^TIMEOUT$' "$OUT/external-curl.log" | sort -u | tr '\n' ' ')
  ((ok == 20)) && verdict external PASS "20/20 from $(hostname), served by: $pods" \
               || verdict external FAIL "$ok/20 from $(hostname)${pods:+, served by: $pods}"
fi
nodeport=$(k -n "$NS" get svc echo -o jsonpath='{.spec.ports[0].nodePort}')
node_ip=$(k get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
log "checking from inside the cluster (VIP ${vip:-?}:80, NodePort $node_ip:$nodeport)"
k -n "$NS" run probe --rm -i --restart=Never --image=curlimages/curl:8.11.1 --command -- sh -c "
  for t in VIP:${vip:-none}:80 NODEPORT:$node_ip:$nodeport; do
    n=\${t%%:*}; a=\${t#*:}; okc=0
    for i in 1 2 3 4 5; do curl -s --max-time 4 -o /dev/null http://\$a/hostname && okc=\$((okc+1)); done
    echo \"\$n \$okc/5\"
  done" >"$OUT/internal-curl.log" 2>&1
grep -q '^VIP 5/5' "$OUT/internal-curl.log" && verdict internal_vip PASS "5/5" \
  || verdict internal_vip FAIL "$(grep '^VIP' "$OUT/internal-curl.log" || echo 'probe failed')"
grep -q '^NODEPORT 5/5' "$OUT/internal-curl.log" && verdict internal_nodeport PASS "5/5" \
  || verdict internal_nodeport FAIL "$(grep '^NODEPORT' "$OUT/internal-curl.log" || echo 'probe failed')"

# ---------------------------------------------------------- 5. MetalLB A/B --
if $AB; then
  if [[ -z ${metallb:-} ]]; then
    verdict metallb_ab SKIP "no MetalLB controller in this cluster"
  else
    log "A/B: MetalLB controller stopped"
    k -n metallb-system scale deploy metallb-controller --replicas=0 >/dev/null; METALLB_SCALED=true
    k -n metallb-system wait --for=delete pod -l app.kubernetes.io/component=controller --timeout=60s >/dev/null 2>&1
    nudge; read -r s0 e0 _ <<<"$(sample metallb-off "$SAMPLE_SECS")"
    log "A/B: MetalLB controller running again"
    k -n metallb-system scale deploy metallb-controller --replicas=1 >/dev/null; METALLB_SCALED=false
    k -n metallb-system rollout status deploy/metallb-controller --timeout=120s >/dev/null 2>&1
    nudge; read -r s1 e1 _ <<<"$(sample metallb-on "$SAMPLE_SECS")"
    k -n metallb-system logs deploy/metallb-controller --since=5m >"$OUT/metallb-controller.log" 2>&1
    if ((e0 == 0 && e1 > 0)); then verdict metallb_ab FAIL "address kept with MetalLB off ($s0/$((s0+e0))), cleared with it on ($e1/$((s1+e1)) empty): MetalLB clears it"
    elif ((e0 == 0 && e1 == 0)); then verdict metallb_ab PASS "address kept either way: MetalLB doesn't interfere"
    else verdict metallb_ab FAIL "address unstable even with MetalLB off ($e0 empty): something else clears it"; fi
  fi
fi

# ----------------------------------------------------------- evidence ------
k -n "$NS" get events --sort-by=.lastTimestamp >"$OUT/events.txt" 2>&1
k -n openstack-system logs ds/openstack-cloud-controller-manager --since=30m 2>&1 |
  grep -E "$NS/echo|${lb_id:-none}" >"$OUT/cloud-controller.log"

# ------------------------------------------------------------- cleanup -----
if ! $KEEP; then
  log "cleaning up (namespace, then the Octavia load balancer)"
  k delete namespace "$NS" --wait=true --timeout=300s >/dev/null 2>&1
  if [[ -n $lb_id ]]; then
    gone=false
    for _ in $(seq 30); do openstack loadbalancer show "$lb_id" >/dev/null 2>&1 || { gone=true; break; }; sleep 10; done
    $gone && verdict cleanup PASS "load balancer $lb_id deleted" \
          || verdict cleanup FAIL "load balancer $lb_id still exists: openstack loadbalancer delete $lb_id --cascade"
  fi
else
  log "--keep: leaving namespace $NS and load balancer ${lb_id:-?} in place"
fi

# -------------------------------------------------------------- report -----
{
  echo "# LoadBalancer test: $CLUSTER, $(date -u +%Y-%m-%dT%H:%MZ)"
  echo
  echo "Template octavia_provider: \`$provider_label\`. MetalLB controller: \`${metallb:-absent}\`. Run from \`$(hostname)\`."
  echo
  echo "| Check | Result | Detail |"
  echo "|---|---|---|"
  for c in pods octavia members floating_ip status_stable external internal_vip internal_nodeport metallb_ab cleanup; do
    [[ -n ${VERDICT[$c]:-} ]] && echo "| $c | ${VERDICT[$c]%%|*} | ${VERDICT[$c]#*|} |"
  done
  echo
  echo "Raw evidence in this folder: environment.txt, lb.json, lb-status.json, status-*.log,"
  echo "service-managedfields.yaml, external-curl.log, internal-curl.log, events.txt,"
  echo "cloud-controller.log, metallb-controller.log (with --ab), run.log."
} >"$REPORT"
echo; cat "$REPORT"
grep -q '| FAIL |' "$REPORT" && exit 1 || exit 0
