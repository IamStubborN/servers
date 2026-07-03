#!/usr/bin/env bash
set -euo pipefail

dnf install -y dnf-plugins-core oracle-epel-release-el9
dnf config-manager --enable ol9_developer_EPEL

dnf install -y \
  bash-completion \
  bat \
  bind-utils \
  bzip2 \
  buildah \
  diffutils \
  fd-find \
  file \
  findutils \
  fzf \
  git-delta \
  git-lfs \
  htop \
  hyperfine \
  iproute \
  iputils \
  jq \
  less \
  lsof \
  nmap-ncat \
  patch \
  podman \
  procps-ng \
  ripgrep \
  rsync \
  ShellCheck \
  skopeo \
  strace \
  tcpdump \
  tmux \
  tree \
  wget \
  zip

required_commands=(
  bat
  buildah
  bzip2
  delta
  diff
  dig
  file
  find
  fzf
  git-lfs
  htop
  hyperfine
  ip
  jq
  less
  lsof
  nc
  patch
  ping
  podman
  ps
  rg
  rsync
  shellcheck
  skopeo
  strace
  tcpdump
  tmux
  tree
  wget
  zip
)

for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null
done

if ! command -v fd >/dev/null 2>&1 && ! command -v fdfind >/dev/null 2>&1; then
  echo "fd-find installed but neither fd nor fdfind is on PATH" >&2
  exit 1
fi
