#!/bin/bash
# =============================================================================
# stress-test.sh — Lab 03 ASG
# Simulates CPU load on all ASG instances to trigger scale-out
# (CPU > 70% for 2 minutes), then observes scale-in.
#
# Local prerequisites: AWS CLI, SSH (key configured or SSM)
# Instance prerequisites: stress (installed via asg-nginx.sh)
# =============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─── Configuration ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

# Retrieve Terraform outputs
ASG_NAME=$(terraform -chdir="$TERRAFORM_DIR" output -raw asg_name)
REGION=$(terraform -chdir="$TERRAFORM_DIR" output -raw region 2>/dev/null || echo "eu-west-3")
ALB_DNS=$(terraform -chdir="$TERRAFORM_DIR" output -raw alb_dns_name)

# Duration of CPU load in seconds (> 120s to trigger 2 alarm periods)
STRESS_DURATION=180

# ─── Colors ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ─── Helpers ──────────────────────────────────────────────────────────────────
log()     { echo -e "${CYAN}[$(date '+%H:%M:%S')]${RESET} $*"; }
success() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓ $*${RESET}"; }
warn()    { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠ $*${RESET}"; }
error()   { echo -e "${RED}[$(date '+%H:%M:%S')] ✗ $*${RESET}"; }
header()  { echo -e "\n${BOLD}$*${RESET}"; echo "$(echo "$*" | sed 's/./-/g')"; }

# ─── Check prerequisites ────────────────────────────────────────────────────
check_prerequisites() {
  header "Prerequisite check"

  for cmd in aws terraform curl; do
    if command -v "$cmd" &>/dev/null; then
      success "$cmd available"
    else
      error "$cmd missing — install it before continuing."
      exit 1
    fi
  done

  # Check that the ASG exists.
  if aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].AutoScalingGroupName' \
      --output text 2>/dev/null | grep -q "$ASG_NAME"; then
    success "ASG '$ASG_NAME' trouvé"
  else
    error "ASG '$ASG_NAME' Not found — did you run terraform apply?"
    exit 1
  fi
}

# ─── Show ASG status ──────────────────────────────────────────────────
show_asg_state() {
  local label="${1:-}"
  echo ""
  [ -n "$label" ] && log "ASG status — $label"

  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[0].{
      Min:MinSize,
      Desired:DesiredCapacity,
      Max:MaxSize,
      Instances:Instances[*].{ID:InstanceId,AZ:AvailabilityZone,State:LifecycleState,Health:HealthStatus}
    }' \
    --output table
}

# ─── Show CloudWatch alarm status ────────────────────────────────────
show_alarm_state() {
  echo ""
  log "CloudWatch alarm status"

  aws cloudwatch describe-alarms \
    --alarm-names "lab03-cpu-high" "lab03-cpu-low" \
    --region "$REGION" \
    --query 'MetricAlarms[*].{Alarm:AlarmName,State:StateValue,Threshold:Threshold,Metric:MetricName}' \
    --output table 2>/dev/null || warn "Alarms not found (different names?)"
}

# ─── ALB Test ──────────────────────────────────────────────────────────────
test_alb() {
  header "ALB Test"
  log "URL : http://$ALB_DNS"

  local attempts=0
  until curl -sf --max-time 5 "http://$ALB_DNS" > /dev/null; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 12 ]; then
      warn "ALB not ready after 60s — check health checks in the console."
      return
    fi
    log "ALB not yet healthy, waiting 5s… ($attempts/12)"
    sleep 5
  done

  success "ALB is responding. Instance responses:"
  echo ""
  for i in $(seq 1 5); do
    echo -n "  Request $i → "
    curl -sf --max-time 5 "http://$ALB_DNS" || echo "(timeout)"
    sleep 1
  done
  echo ""
  log "→ You should see different hostnames = load balancing active."
}

# ─── Retrieve ASG instance IPs ─────────────────────────────────
get_instance_ips() {
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
    --output text | tr '\t' '\n' | while read -r instance_id; do
      aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --region "$REGION" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text
    done
}

# ─── Wainting for SMM to be ready ─────────────────────────────
wait_for_ssm() {
  local instance_id="$1"
  local max_attempts=20
  local attempt=0

  log "Attente enregistrement SSM pour $instance_id..."

  until aws ssm describe-instance-information \
      --filters "Key=InstanceIds,Values=$instance_id" \
      --region "$REGION" \
      --query 'InstanceInformationList[0].InstanceId' \
      --output text 2>/dev/null | grep -q "$instance_id"; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
      error "SSM non disponible après $((max_attempts * 15))s sur $instance_id"
      return 1
    fi
    log "SSM pas encore prêt... ($attempt/$max_attempts)"
    sleep 15
  done

  success "SSM prêt sur $instance_id"
}

# ─── Run stress via SSM (no SSH key required) ─────────────────────────────
run_stress_via_ssm() {
  local instance_id="$1"
  local duration="$2"

  log "Starting stress on $instance_id via SSM (${duration}s)…"

  aws ssm send-command \
    --instance-ids "$instance_id" \
    --document-name "AWS-RunShellScript" \
    --region "$REGION" \
    --parameters "commands=[
      'nohup stress --cpu $(nproc) --timeout ${duration} > /tmp/stress.log 2>&1 &',
      'echo \"Stress started — PID: \$!\"'
    ]" \
    --output text \
    --query 'Command.CommandId' 2>/dev/null || {
      warn "SSM failed on $instance_id — instance not yet registered?"
      return 1
    }

  success "Stress started on $instance_id"
}

# ─── Monitoring phase ────────────────────────────────────────────────────
watch_scaling() {
  local duration="$1"
  local start
  start=$(date +%s)
  local initial_count
  initial_count=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$REGION" \
    --query 'AutoScalingGroups[0].DesiredCapacity' \
    --output text)

  log "Monitoring for ${duration}s (initial instances: $initial_count)…"
  log "→Scale-out expected if CPU > 70% for 2 min (alarm: evaluation_periods=2, period=60s)"
  echo ""

  local scaled_out=false
  while true; do
    local now elapsed current_count cpu_avg
    now=$(date +%s)
    elapsed=$((now - start))

    current_count=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].DesiredCapacity' \
      --output text)

    # Average CPU over the last 2 minutes via CloudWatch
    cpu_avg=$(aws cloudwatch get-metric-statistics \
      --namespace AWS/EC2 \
      --metric-name CPUUtilization \
      --dimensions Name=AutoScalingGroupName,Value="$ASG_NAME" \
      --start-time "$(date -u -d '3 minutes ago' '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -v-3M '+%Y-%m-%dT%H:%M:%SZ')" \
      --end-time "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
      --period 120 \
      --statistics Average \
      --region "$REGION" \
      --query 'sort_by(Datapoints, &Timestamp)[-1].Average' \
      --output text 2>/dev/null || echo "N/A")

    printf "${CYAN}[%3ds]${RESET} Instances: ${BOLD}%s${RESET}  |  CPU avg: ${YELLOW}%s%%${RESET}\n" \
      "$elapsed" "$current_count" "${cpu_avg%.*}"

    # Detect scale-out
    if [ "$current_count" -gt "$initial_count" ] && [ "$scaled_out" = false ]; then
      scaled_out=true
      success "SCALE-OUT TRIGGERED ! ${initial_count} → ${current_count} instances"
      show_asg_state "après scale-out"
    fi

    # Stopping monitoring after the duration
    if [ "$elapsed" -ge "$duration" ]; then
      break
    fi

    sleep 15
  done
}

# ─── Wait for scale-in ───────────────────────────────────────────────────────
wait_for_scale_in() {
  header "Scale-in phase (stress stopped — waiting for CPU < 30%)"
  log "Scale-in cooldown is 300s + 2 periods of 60s = ~7 min minimum"
  log "Monitoring every 30s..."
  echo ""

  local max_wait=900 # 15 min max
  local start
  start=$(date +%s)

  while true; do
    local now elapsed current_count
    now=$(date +%s)
    elapsed=$((now - start))
    current_count=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].DesiredCapacity' \
      --output text)

    printf "${CYAN}[%3ds]${RESET} Current instances: ${BOLD}%s${RESET}\n" "$elapsed" "$current_count"

    if [ "$current_count" -le 2 ]; then
      success "SCALE-IN TRIGGERED ! Back to $current_count instances"
      break
    fi

    if [ "$elapsed" -ge "$max_wait" ]; then
      warn "Timeout reached — scale-in not yet triggered"
      warn "Check the cpu-low alarm in the CloudWatch console"
      break
    fi

    sleep 30
  done
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}║     Lab 03 — ASG Stress Test                 ║${RESET}"
  echo -e "${BOLD}╚══════════════════════════════════════════════╝${RESET}"
  echo ""
  log "ASG     : $ASG_NAME"
  log "Region  : $REGION"
  log "ALB     : $ALB_DNS"
  log "Duration   : ${STRESS_DURATION}s of CPU load"
  echo ""

  # 1. Prerequisites
  check_prerequisites

  # 2. Initial state
  show_asg_state "initial"
  show_alarm_state

  # 3. ALB Test
  test_alb

  # 4. Retrieve InService instances
  header "Retrieving instances"
  mapfile -t INSTANCE_IDS < <(
    aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' \
      --output text | tr '\t' '\n'
  )

  if [ "${#INSTANCE_IDS[@]}" -eq 0 ]; then
    error "No InService instances in the ASG"
    error "Wait for instances to become healthy (health_check_grace_period=120s)"
    exit 1
  fi

  success "${#INSTANCE_IDS[@]} instance(s) InService : ${INSTANCE_IDS[*]}"

  # 5. Run stress on all instances via SSM
  header "Starting stress test (${STRESS_DURATION}s)"
  warn "Instances must be registered in SSM (policy AmazonSSMManagedInstanceCore required)"

  for instance_id in "${INSTANCE_IDS[@]}"; do
    wait_for_ssm "$instance_id" && run_stress_via_ssm "$instance_id" "$STRESS_DURATION" || true
  done

  echo ""
  log "→ Open the AWS console to monitor in real time :"
  log "   EC2 > Auto Scaling Groups > lab03-asg > Activity"
  log "   CloudWatch > Alarms > lab03-cpu-high"
  echo ""

  # 6. Monitor scale-out over the stress duration + margin
  header "Scale-out monitoring"
  watch_scaling $((STRESS_DURATION + 60))

  # 7. Monitor scale-in after stopping stress
  wait_for_scale_in

  # 8. Final state
  header "Final state"
  show_asg_state "final"
  show_alarm_state

  echo ""
  success "Stress test completed !"
  echo ""
  log "Next steps :"
  log "  • Check ASG events in the console: EC2 > Auto Scaling Groups > Activity"
  log "  • Compare CloudWatch metrics before/during/after"
  log "  • Destroy the infrastructure: cd terraform && terraform destroy -auto-approve"
}

main "$@"
