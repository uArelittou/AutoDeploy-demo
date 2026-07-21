#!/bin/bash
# health_check.sh —— 健康检查脚本
# 作用：探活应用的 /health 接口，判断应用是否正常运行
# 返回值：健康返回 0，挂了返回 1（shell 约定 0=成功）
# 谁调用它：deploy.sh 调用它，根据返回值决定「部署完成」还是「触发回滚」


# source = 在当前 shell 执行 config.sh，把它定义的变量读进来
# 这样 PORT、MAX_RETRIES、RETRY_INTERVAL 这些变量就能用了
# ${BASH_SOURCE[0]%/*} = 当前脚本所在目录，保证在哪运行都能找到同目录的 config.sh
source "${BASH_SOURCE[0]%/*}/config.sh"

# 应用健康检查 URL
HEALTH_URL="http://localhost:${PORT}/health"

echo "开始健康检查: $HEALTH_URL"

# 循环探活，最多 MAX_RETRIES 次
for i in $(seq 1 $MAX_RETRIES); do
    # curl 探活：
    # -s 静默模式（不显示进度条）
    # -o /dev/null 把响应体丢弃（我们只关心状态码，不关心内容）
    # -w '%{http_code}' 只输出 HTTP 状态码（如 200、500）
    # 整个命令的输出赋值给 HTTP_CODE
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$HEALTH_URL")

    # 状态码 200 = 应用正常
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ 健康检查通过（第 $i 次尝试，状态码 $HTTP_CODE）"
        exit 0   # 返回 0 表示成功
    fi

    # 没通过，等 RETRY_INTERVAL 秒再试
    # 为什么等：应用刚启动可能还没监听端口，给它点时间就绪
    echo "  第 $i 次探活未通过（状态码 $HTTP_CODE），${RETRY_INTERVAL} 秒后重试..."
    sleep $RETRY_INTERVAL
done

# 跑到这说明 MAX_RETRIES 次全失败，应用挂了
echo "✗ 健康检查失败：连续 $MAX_RETRIES 次探活均未通过"
exit 1   # 返回 1 表示失败，deploy.sh 收到这个就会触发回滚
