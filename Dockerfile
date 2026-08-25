# 開発用イメージです。WSL に Node と Ruby がネイティブで入っていないため、
# 開発はすべてこのコンテナの中で行います。本番用のイメージではありません。
FROM ruby:3.3-bookworm

ARG NODE_MAJOR=22

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Tokyo

# Node.js と PostgreSQL クライアント、ビルドに必要なものを入れます。
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git build-essential \
      libpq-dev postgresql-client tzdata \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
 && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
      > /etc/apt/sources.list.d/nodesource.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs \
 && rm -rf /var/lib/apt/lists/*

# 時刻は JST に揃えます。
RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && echo ${TZ} > /etc/timezone

# ホスト（WSL）のユーザーと UID を揃えて、生成されたファイルの所有者がずれないようにします。
ARG USER_NAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USER_NAME} 2>/dev/null || true \
 && useradd --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USER_NAME} 2>/dev/null || true \
 && mkdir -p /workspace /bundle /node_modules_cache \
 && chown -R ${USER_UID}:${USER_GID} /workspace /bundle /node_modules_cache

ENV BUNDLE_PATH=/bundle \
    BUNDLE_APP_CONFIG=/bundle \
    GEM_HOME=/bundle \
    PATH=/bundle/bin:${PATH}

USER ${USER_NAME}
WORKDIR /workspace

CMD ["sleep", "infinity"]
