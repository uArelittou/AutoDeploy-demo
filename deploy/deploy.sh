#!/bin/bash
# deploy.sh —— 部署 + 自动回滚主脚本
# 作用：拉新镜像 → 起容器 → 健康检查 → 失败自动回滚到上一版本
# 这是第三阶段的核心，简历能重点讲


# set -e：任何命令失败立刻退出脚本（不继续往下跑）
# pipefail：管道中任一命令失败整个管道算失败
# 注意：不用 set -u，因为 versions.txt 动态 source 进来的变量可能未定义
#       和 -u 冲突，生产 shell 脚本一般只开 -e + pipefail
set -eo pipefail

# 读配置
source "${BASH_SOURCE[0]%/*}/config.sh"

# 回滚函数：失败时调用，恢复到上一版本
rollback() {
    echo "=== 开始回滚 ==="

    # 停掉刚才起的新容器（可能还半死不活地跑着）
    # -f 强制：即使容器在运行也直接删，避免 rm 残留导致后面 run 时容器名冲突
    docker rm -f "$CONTAINER" 2>/dev/null || true

    # 检查有没有可回滚的版本
    # 回滚目标是 CURRENT_VERSION（当前在跑的、已验证能用的版本），不是 PREVIOUS
    # PREVIOUS 是更早的版本，current 才是「上一个成功版本」
    if [ -z "${CURRENT_VERSION:-}" ]; then
        # 首次部署就挂了，日志里没有 current，没有可回滚版本
        echo "✗ 无历史版本可回滚（首次部署失败），应用未上线"
        exit 1
    fi

    echo "回滚到上一版本: ${IMAGE}:${CURRENT_VERSION}"
    # 用上一版本镜像重新起容器
    docker run -d --name "$CONTAINER" -p "${PORT}:${PORT}" "${IMAGE}:${CURRENT_VERSION}"

    # 回滚后也要健康检查，确认旧版本确实能起来（防回滚到坏版本）
    if bash "${BASH_SOURCE[0]%/*}/health_check.sh"; then
        echo "✓ 回滚成功，已恢复到 ${CURRENT_VERSION}"
        # 写日志：current 保持回到的好版本，previous 清空（坏版本不留历史）
        # 追加一行历史记录（# 开头，source 时被当注释跳过，不报错）
        {
            echo "current=${CURRENT_VERSION}"
            echo "previous="
        } > "$VERSIONS_FILE"
        echo "# [$(date '+%Y-%m-%d %H:%M:%S')] 版本 ${NEW_VERSION} 部署失败，已回滚到 ${CURRENT_VERSION}" >> "$VERSIONS_FILE"
        exit 1   # 仍然返回 1：虽然回滚了，但本次部署是失败的
    else
        echo "✗ 回滚后健康检查仍失败，旧版本也起不来，需人工介入"
        # 回滚失败：记录失败的新版本，current 保留供人工排查
        {
            echo "current=${NEW_VERSION}"
            echo "previous=${CURRENT_VERSION}"
        } > "$VERSIONS_FILE"
        echo "# [$(date '+%Y-%m-%d %H:%M:%S')] 版本 ${NEW_VERSION} 部署失败，回滚也失败（旧版本起不来），需人工介入" >> "$VERSIONS_FILE"
        exit 1
    fi
}

# ============ 主流程开始 ============

# 1. 生成新版本号：时间戳（年月日_时分秒），保证每次部署唯一
# date +%Y%m%d_%H%M%S 输出如 20260721_153045
# 注意：脚本里用 date 没问题（不在 workflow 脚本本体里）
NEW_VERSION=$(date +%Y%m%d_%H%M%S)
echo "=== 部署新版本: ${IMAGE}:${NEW_VERSION} ==="

# 2. 读取当前版本记录（如果存在）
# versions.txt 格式：
#   current=旧版本
#   previous=更旧的版本
if [ -f "$VERSIONS_FILE" ]; then
    source "$VERSIONS_FILE"   # 读进 CURRENT_VERSION 和 PREVIOUS_VERSION
else
    CURRENT_VERSION=""
    PREVIOUS_VERSION=""
fi

# 3. 拉最新镜像（latest 是 GHCR 上最新的构建产物）
echo "拉取最新镜像..."
docker pull "${IMAGE}:latest"

# 4. 给拉下来的镜像打上新版本号 tag
# docker tag 源镜像 目标镜像：把 latest 重新打标签为时间戳版本
# 这样每次部署都有唯一可追溯的版本，回滚能精确指到某个时间点
docker tag "${IMAGE}:latest" "${IMAGE}:${NEW_VERSION}"

# 5. 停掉当前在跑的容器（准备换新版）
if docker ps -a | grep -q "$CONTAINER"; then
    echo "停止当前容器..."
    # -f 强制删除（含 stop），避免残留容器名冲突
    docker rm -f "$CONTAINER" 2>/dev/null || true
fi

# 6. 用新版本镜像起新容器
# -d 后台运行
# --name 指定容器名（方便后面 stop/rm）
# -p 端口映射 宿主机:容器
echo "启动新容器（版本 ${NEW_VERSION}）..."
docker run -d --name "$CONTAINER" -p "${PORT}:${PORT}" "${IMAGE}:${NEW_VERSION}"

# 7. 健康检查（关键环节）
# 直接调 health_check.sh，根据它的返回值决定下一步
if bash "${BASH_SOURCE[0]%/*}/health_check.sh"; then
    # 健康检查通过 → 部署成功
    echo "✓ 部署成功: ${NEW_VERSION}"

    # 写日志：current 更新为新版本，previous 挪到旧 current（旧版变历史版）
    # 用 {} 块重定向一次性写两行，原子性好
    {
        echo "current=${NEW_VERSION}"
        echo "previous=${CURRENT_VERSION}"
    } > "$VERSIONS_FILE"
    # 追加历史记录（# 开头注释，source 时跳过不报错）
    echo "# [$(date '+%Y-%m-%d %H:%M:%S')] 版本 ${NEW_VERSION} 部署成功" >> "$VERSIONS_FILE"

    exit 0
else
    # 健康检查失败 → 触发回滚
    echo "✗ 健康检查失败，触发回滚..."
    rollback
fi
