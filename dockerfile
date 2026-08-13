# Base: official Terraform image (Alpine-based)
FROM hashicorp/terraform:1.7.5

ARG GCLOUD_VERSION=450.0.0

# Alpine base — gcloud's official installer targets Debian/RPM/tarball,
# so the portable tarball install is the reliable option here, not apt/yum.
RUN apk add --no-cache curl python3 bash

RUN curl -fsSL -o /tmp/gcloud.tar.gz \
      "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-${GCLOUD_VERSION}-linux-x86_64.tar.gz" \
    && tar -xzf /tmp/gcloud.tar.gz -C /usr/local \
    && rm /tmp/gcloud.tar.gz \
    && /usr/local/google-cloud-sdk/install.sh \
      --quiet \
      --usage-reporting=false \
      --path-update=false \
    && /usr/local/google-cloud-sdk/bin/gcloud components install kubectl gke-gcloud-auth-plugin --quiet

ENV PATH="/usr/local/google-cloud-sdk/bin:${PATH}"
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True

WORKDIR /workspace

ENTRYPOINT ["/bin/bash"]