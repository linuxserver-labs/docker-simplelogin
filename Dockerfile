FROM ghcr.io/linuxserver/baseimage-alpine:edge AS buildstage

ARG SL_RELEASE

RUN \
  echo "**** install build packages ****" && \
  apk add \
    nodejs \
    npm \
    p7zip \
    zip

RUN \
  echo "**** grab simplelogin ****" && \
  mkdir /simplelogin && \
  if [ -z ${SL_RELEASE+x} ]; then \
    SL_RELEASE=$(curl -sX GET "https://api.github.com/repos/simple-login/app/releases/latest" \
      | jq -r '. | .tag_name'); \
  fi && \
  curl -o \
    /tmp/simplelogin.tar.gz -L \
    "https://github.com/simple-login/app/archive/${SL_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/simplelogin.tar.gz -C \
    /simplelogin/ --strip-components=1

RUN \
  echo "**** build simplelogin ****" && \
  cd /simplelogin/static && \
  npm ci

FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="quietsy"

COPY --from=buildstage /simplelogin/ /code/

WORKDIR /code

ENV PATH="$HOME/.local/bin:/code/.venv/bin:$PATH"

# Install deps
RUN \
  echo "**** install build packages ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    libre2-dev \
    pkg-config \
    ninja-build \
    clang && \
  curl -o /tmp/uv-installer.sh -L https://astral.sh/uv/install.sh && \
  sh /tmp/uv-installer.sh && \
  uv python install `cat .python-version` && \
  uv sync --locked && \
  echo "**** install runtime packages ****" && \
  apt-get install -y \
    gnupg \
    libre2-10 && \
  echo "**** cleanup ****" && \
  apt-get purge -y \
    git \
    libre2-dev \
    pkg-config \
    ninja-build \
    clang && \
  apt-get autoremove -y && \
  apt-get autoclean -y && \
  rm -rf \
    /var/lib/apt/lists \
    $HOME/.cache \
    /tmp/*

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 7777
VOLUME /config
