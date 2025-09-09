# Usar imagen base de Kaniko que ya incluye el executor
FROM gcr.io/kaniko-project/executor:v1.24.0 as kaniko

# Imagen base para nuestro container
FROM debian:bookworm-slim

ARG AWSCLI_VERSION=2.17.40

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin

# Paquetes base
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget bash git jq unzip tar xz-utils gnupg openssh-client \
 && rm -rf /var/lib/apt/lists/*

# Copiar el executor de Kaniko
COPY --from=kaniko /kaniko/executor /usr/local/bin/kaniko

# AWS CLI v2
RUN curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

WORKDIR /work
COPY publish.sh /usr/local/bin/publish.sh
RUN chmod +x /usr/local/bin/publish.sh

CMD ["/usr/local/bin/publish.sh"]
