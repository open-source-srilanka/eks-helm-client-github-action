FROM alpine:3.18

# Metadata
LABEL maintainer="dinushchathurya21@gmail.com"
LABEL version="2.0.0"
LABEL description="EKS Helm Client with private infrastructure support"
LABEL org.opencontainers.image.source="https://github.com/open-source-srilanka/eks-helm-client-github-action"
LABEL org.opencontainers.image.description="Deploy Helm charts to EKS clusters with support for private clusters and registries"
LABEL org.opencontainers.image.licenses="MIT"

# Install base packages
RUN apk add --no-cache \
    ca-certificates \
    bash \
    git \
    gnupg \
    jq \
    curl \
    gettext \
    openssl \
    py3-pip \
    python3 \
    netcat-openbsd \
    && pip3 install --upgrade awscli \
    && rm -rf /var/cache/apk/*

# Set environment variables
ENV KUBECONFIG="/opt/kubernetes/config"
ENV HELM_HOME="/opt/helm"
ENV XDG_CONFIG_HOME="/opt/helm" 
ENV HELM_CACHE_HOME="/opt/helm/cache"
ENV HELM_CONFIG_HOME="/opt/helm"
ENV HELM_DATA_HOME="/opt/helm"
ENV PATH="/usr/local/bin:$PATH"

# Install kubectl (version will be overridden by input parameter)
ARG KUBECTL_VERSION="1.28.4"
RUN curl -s -L "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# Install Helm (version will be overridden by input parameter)
ARG HELM_VERSION="3.13.3"
RUN curl -s -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar -xzO linux-amd64/helm > /usr/local/bin/helm \
    && chmod +x /usr/local/bin/helm

# Install AWS IAM Authenticator
ARG IAM_AUTHENTICATOR_VERSION="0.6.14"
RUN curl -o aws-iam-authenticator "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/v${IAM_AUTHENTICATOR_VERSION}/aws-iam-authenticator_${IAM_AUTHENTICATOR_VERSION}_linux_amd64" \
    && chmod +x ./aws-iam-authenticator \
    && mv ./aws-iam-authenticator /usr/local/bin

# Install eksctl for additional EKS operations
RUN curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp \
    && mv /tmp/eksctl /usr/local/bin

# Create necessary directories with proper permissions
RUN mkdir -p /opt/kubernetes /opt/helm /opt/scripts && \
    chmod a+rwx /opt/kubernetes /opt/helm /opt/scripts

# Create non-root user for better security
RUN addgroup -g 1000 runner && \
    adduser -D -u 1000 -G runner runner && \
    chown -R runner:runner /opt/kubernetes /opt/helm /opt/scripts

# Copy configuration files and scripts
COPY templates/config.template /config.template
COPY templates/private-config.template /private-config.template
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/health-check.sh /health-check.sh
COPY scripts/setup-tools.sh /setup-tools.sh
COPY scripts/cleanup.sh /cleanup.sh

# Set proper permissions for scripts
RUN chmod +x /entrypoint.sh /health-check.sh /setup-tools.sh /cleanup.sh && \
    chown runner:runner /entrypoint.sh /health-check.sh /setup-tools.sh /cleanup.sh

# Set working directory
WORKDIR /opt/scripts

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD /health-check.sh

# Security: Use non-root user for execution
USER runner

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]