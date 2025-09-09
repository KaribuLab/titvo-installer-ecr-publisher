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
echo "GIT_URL=${GIT_URL:-}"
echo "IMAGE_REPO=${IMAGE_REPO:-}"
echo "GIT_REF=${GIT_REF:-main}"
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

CONTEXT="${SRC}/${CONTEXT_PATH:-.}"
DOCKERFILE_PATH="${CONTEXT}/${DOCKERFILE:-Dockerfile}"
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

echo "==> BuildKit daemonless → ${DEST_IMAGE}"
BK_ARGS=( build
  --frontend=dockerfile.v0
  --local "context=${CONTEXT}"
  --local "dockerfile=${CONTEXT}"
  --opt "filename=$(basename "$DOCKERFILE_PATH")"
  --output "type=image,name=${DEST_IMAGE},push=true"
)

# Build args: {"KEY":"VAL"}
if [[ -n "${BUILD_ARGS_JSON:-}" ]]; then
  echo "$BUILD_ARGS_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | \
  while IFS= read -r kv; do
    BK_ARGS+=( --opt "build-arg:${kv}" )
  done
fi

# Iniciar buildkitd en segundo plano
echo "==> Iniciando buildkitd..."
mkdir -p /run/buildkit
buildkitd &
BUILDKITD_PID=$!

# Esperar a que buildkitd esté listo
echo "==> Esperando a que buildkitd esté listo..."
for i in {1..30}; do
  if buildctl debug workers >/dev/null 2>&1; then
    echo "==> buildkitd está listo"
    break
  fi
  echo "==> Esperando... ($i/30)"
  sleep 1
done

# Verificar que buildkitd está funcionando
if ! buildctl debug workers >/dev/null 2>&1; then
  echo "ERROR: buildkitd no se inició correctamente"
  kill $BUILDKITD_PID 2>/dev/null || true
  exit 1
fi

# Ejecutar el build
echo "==> Ejecutando build..."
buildctl "${BK_ARGS[@]}"

# Limpiar procesos
echo "==> Limpiando..."
kill $BUILDKITD_PID 2>/dev/null || true
echo "==> OK. Image published: ${DEST_IMAGE}"