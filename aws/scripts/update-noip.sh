#!/bin/bash
set -euo pipefail

TF_DIR="$(cd "$(dirname "$0")/.." && pwd)"

NOIP_HOST="${NOIP_HOST:?missing NOIP_HOST}"
NOIP_USER="${NOIP_USER:?missing NOIP_USER}"
NOIP_PASS="${NOIP_PASS:?missing NOIP_PASS}"
NLB_DNS=$(terraform -chdir="$TF_DIR" output -raw alb_dns)

echo "===== START ====="
echo "NLB DNS: $NLB_DNS"

IPS=$(dig +short "$NLB_DNS")

if [ -z "$IPS" ]; then
  echo "Erro: não foi possível resolver o DNS do NLB"
  exit 1
fi

echo "IPs encontrados:"
echo "$IPS"

NLB_IP=""

for ip in $IPS; do
  echo "Testar IP: $ip"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout 2 \
    --max-time 5 \
    "http://$ip" || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "IP saudável: $ip HTTP $HTTP_CODE"
    NLB_IP="$ip"
    break
  else
    echo "IP não respondeu corretamente: $ip HTTP $HTTP_CODE"
  fi
done

if [ -z "$NLB_IP" ]; then
  echo "Erro: nenhum IP saudável encontrado"
  exit 1
fi

echo "IP escolhido final: $NLB_IP"

RESPONSE=$(curl -s \
  -u "$NOIP_USER:$NOIP_PASS" \
  "https://dynupdate.no-ip.com/nic/update?hostname=$NOIP_HOST&myip=$NLB_IP")

echo "Resposta No-IP: $RESPONSE"

sleep 3

echo "Verificação DNS:"
dig +short "$NOIP_HOST"

echo "===== DONE ====="

