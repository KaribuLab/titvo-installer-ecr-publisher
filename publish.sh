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
DEBUG=${DEBUG:-false}

log(){
    local level=$1
    local message=$2
    echo "[$level]: ${message}"
}

log_debug(){
    local message=$1
    if [ "${DEBUG}" == "true" ]; then
        log "DEBUG" "$message"
    fi
}

log_info(){
    local message=$1
    log "INFO" "$message"
}

log_error(){
    local message=$1
    log "ERROR" "$message"
}

log_info "==> Params"
log_info "GIT_URL=${GIT_URL}"
log_info "IMAGE_REPO=${IMAGE_REPO}"
log_info "GIT_REF=${GIT_REF}"
log_info "CONTEXT_PATH=${CONTEXT_PATH}"
log_info "DOCKERFILE=${DOCKERFILE}"
log_info "IMAGE_TAG=${IMAGE_TAG}"

if [[ -z "${GIT_URL:-}" || -z "${IMAGE_REPO:-}" ]]; then
  log_error "GIT_URL e IMAGE_REPO are required." >&2
  exit 2
fi

log_info "==> Getting AWS Account ID"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text || log_error "AWS Account ID is required.")
REGISTRY_URL="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

if [[ -z "${ACCOUNT_ID:-}" || -z "${REGION:-}" ]]; then
  log_error "AWS Account ID and Region are required." >&2
  exit 2
fi

log_info "==> Registry"
log_info "ACCOUNT_ID=${ACCOUNT_ID}"
log_info "REGION=${REGION}"
log_info "REGISTRY_URL=${REGISTRY_URL}"

WORK=/work
SRC="$WORK/src"

log_info "==> Clonando repo"
git clone --depth 1 --branch "$GIT_REF" "$GIT_URL" "$SRC"

log_debug "List of src files: $( ls -la $SRC )"

CONTEXT="${SRC}/${CONTEXT_PATH}"
DOCKERFILE_PATH="${CONTEXT}/${DOCKERFILE}"
[[ -f "$DOCKERFILE_PATH" ]] || { log_error "$DOCKERFILE_PATH not found"; exit 5; }

DEST_IMAGE="${REGISTRY_URL}/${IMAGE_REPO}:${IMAGE_TAG}"

log_info "==> Login to ECR: ${REGISTRY_URL} (region=${REGION})"
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

log_info "==> Kaniko build → ${DEST_IMAGE}"

# Preparar argumentos de build para Kaniko
KANIKO_ARGS=(
  --dockerfile="${DOCKERFILE_PATH}"
  --context="${CONTEXT}"
  --destination="${DEST_IMAGE}"
  --cache=false
)

# Build args: {"KEY":"VAL"}
if [[ -n "${BUILD_ARGS_JSON:-}" ]]; then
  log_info "==> Configurando build args..."
  echo "$BUILD_ARGS_JSON" | jq -r 'to_entries[] | "\(.key)=\(.value)"' | \
  while IFS= read -r kv; do
    KANIKO_ARGS+=( --build-arg "${kv}" )
  done
fi

# Ejecutar Kaniko (diseñado específicamente para containers sin privilegios)
log_info "==> Ejecutando build con Kaniko..."
kaniko "${KANIKO_ARGS[@]}"

log_info "==> OK. Image published: ${DEST_IMAGE}"
