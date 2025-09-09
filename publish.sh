#!/usr/bin/env bash
set -euo pipefail

if [ $# -gt 0 ]; then
  exec "$@"
  exit 0
fi

GIT_REF=${GIT_REF:-main}
CONTEXT_PATH=${CONTEXT_PATH:-.}
DOCKERFILE=${DOCKERFILE:-Dockerfile}
IMAGE_TAG=${IMAGE_TAG:-latest}

echo "==> Params"
echo "GIT_URL=${GIT_URL}"
echo "IMAGE_REPO=${IMAGE_REPO}"
echo "GIT_REF=${GIT_REF}"
echo "CONTEXT_PATH=${CONTEXT_PATH}"
echo "DOCKERFILE=${DOCKERFILE}"
echo "IMAGE_TAG=${IMAGE_TAG}"

if [[ -z "${GIT_URL:-}" || -z "${IMAGE_REPO:-}" ]]; then
  echo "ERROR: GIT_URL e IMAGE_REPO are required." >&2
  exit 2
fi

echo "==> Getting AWS Account ID"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text || echo "ERROR: AWS Account ID is required.")
REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

if [[ -z "${ACCOUNT_ID:-}" || -z "${REGION:-}" ]]; then
  echo "ERROR: AWS Account ID and Region are required." >&2
  exit 2
fi

echo "==> Registry"
echo "ACCOUNT_ID=${ACCOUNT_ID}"
echo "REGION=${REGION}"
echo "REGISTRY_URL=${REGISTRY_URL}"

WORK=/work
SRC="$WORK/src"

echo "==> Clonando repo"
git clone --depth 1 --branch "$GIT_REF" "$GIT_URL" "$SRC"

CONTEXT="${SRC}/${CONTEXT_PATH}"
DOCKERFILE_PATH="${CONTEXT}/${DOCKERFILE}"
[[ -f "$DOCKERFILE_PATH" ]] || { echo "ERROR: $DOCKERFILE_PATH not found"; exit 5; }

DEST_IMAGE="${REGISTRY_URL}/${IMAGE_REPO}:${IMAGE_TAG}"

echo "==> Login to ECR: ${REGISTRY_URL} (region=${REGION})"
# Crear directorio .docker si no existe
mkdir -p ~/.docker

# Obtener token de ECR y configurar credenciales para buildctl
ECR_TOKEN=$(aws ecr get-login-password --region "${REGION}")
echo "{
  \"auths\": {
    \"${REGISTRY_URL}\": {
      \"auth\": \"$(echo -n "AWS:${ECR_TOKEN}" | base64 -w0)\"
    }
  }
}" > ~/.docker/config.json

chmod 600 ~/.docker/config.json

echo "==> Kaniko build → ${DEST_IMAGE}"

# Preparar argumentos de build para Kaniko
KANIKO_ARGS=(
  --dockerfile="${DOCKERFILE_PATH}"
  --context="${CONTEXT}"
  --destination="${DEST_IMAGE}"
  --cache=false
)

# Build args: {"KEY":"VAL"}
if [[ -n "${BUILD_ARGS_JSON:-}" ]]; then
  echo "==> Configurando build args..."
  echo "$BUILD_ARGS_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | \
  while IFS= read -r kv; do
    KANIKO_ARGS+=( --build-arg "${kv}" )
  done
fi

# Ejecutar Kaniko (diseñado específicamente para containers sin privilegios)
echo "==> Ejecutando build con Kaniko..."
kaniko "${KANIKO_ARGS[@]}"

echo "==> OK. Image published: ${DEST_IMAGE}"