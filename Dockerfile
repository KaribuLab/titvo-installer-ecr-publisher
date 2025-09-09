FROM debian:bookworm-slim

ARG AWSCLI_VERSION=2.17.40
ARG BUILDKIT_VERSION=v0.23.2

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin

# Paquetes base
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget bash git jq unzip tar xz-utils gnupg openssh-client \
    runc \
 && rm -rf /var/lib/apt/lists/*

# BuildKit (latest version)
RUN mkdir -p /tmp/buildkit && \
    curl -fsSL -o /tmp/buildkit.tgz \
      "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-amd64.tar.gz" && \
    tar -C /tmp/buildkit -xzf /tmp/buildkit.tgz && \
    mv /tmp/buildkit/bin/buildctl /usr/local/bin/buildctl && \
    mv /tmp/buildkit/bin/buildkitd /usr/local/bin/buildkitd && \
    chmod +x /usr/local/bin/buildctl /usr/local/bin/buildkitd && \
    rm -rf /tmp/buildkit /tmp/buildkit.tgz

# AWS CLI v2
RUN curl -fsSL -o /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWSCLI_VERSION}.zip" && \
    unzip -q /tmp/awscliv2.zip -d /tmp && \
    /tmp/aws/install && \
    rm -rf /tmp/aws /tmp/awscliv2.zip

WORKDIR /work
COPY publish.sh /usr/local/bin/publish.sh
RUN chmod +x /usr/local/bin/publish.sh

CMD ["/usr/local/bin/publish.sh"]
