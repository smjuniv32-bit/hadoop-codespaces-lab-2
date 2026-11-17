#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Docker 설치 확인
if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker not found"
    exit 1
fi

# Docker 실행 상태 확인
if ! docker info >/dev/null 2>&1; then
    echo "[ERROR] Docker daemon not running"
    exit 1
fi

echo "Checking Hadoop cluster..."

# 최대 45회 확인
for i in $(seq 1 45)
do
    report=$(docker compose exec -T namenode hdfs dfsadmin -report 2>/dev/null) || report=""

    # Live DataNode 수 추출
    count=$(echo "$report" | sed -n 's/^[[:space:]]*Live datanodes (\([0-9][0-9]*\)).*/\1/p' | head -n 1)

    # DataNode가 2개 이상이면 성공
    if [[ "${count:-0}" =~ ^[0-9]+$ ]] && (( count >= 2 )); then
        echo "[OK] Hadoop cluster ready"
        echo "Live DataNodes: $count"
        echo "$report" | grep -E 'Live datanodes|Dead datanodes|Configured Capacity' || true
        exit 0
    fi

    echo "Waiting for DataNodes... ($i/45)"
    sleep 3
done

echo "[ERROR] DataNodes not ready"
docker compose ps
docker compose logs --tail=35 namenode datanode1 datanode2
exit 1