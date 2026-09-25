#!/bin/bash
# SessionStart 钩子：会话一开场就把外置大脑（Ombre Brain）的记忆注入上下文。
#
# 它 GET $OMBRE_BRAIN_URL/breath-hook（纯文本响应），拿到的是：
# 置顶核心准则、权重最高的未解决记忆、最近 3 条 I（自我认知）、双方各最新一封信。
#
# 设计上只有一条铁律：绝不拖累会话启动。
#   · 少任何一个环境变量  → 安静退出 0，会话照常开始，只是没带记忆
#   · 大脑不可达/超时/401 → 同样安静退出 0，绝不让会话起不来
#   · token 经 curl --config 从 stdin 传入，不进命令行参数，
#     因此不会出现在 ps 的进程列表里（README 也要求 token 只走请求头，
#     不进 URL、代理日志和浏览器历史）
#   · 幂等、无交互、不写任何文件

set -uo pipefail   # 故意不加 -e：任何一步出错都要走「安静放弃」而不是中断会话

BRAIN_URL="${OMBRE_BRAIN_URL:-}"
HOOK_TOKEN="${OMBRE_HOOK_TOKEN:-}"

[ -n "$BRAIN_URL" ]  || exit 0
[ -n "$HOOK_TOKEN" ] || exit 0

BRAIN_URL="${BRAIN_URL%/}"

memories="$(
  printf 'header = "x-ombre-hook-token: %s"\n' "$HOOK_TOKEN" \
    | curl --silent --show-error --fail \
           --connect-timeout 5 --max-time 25 \
           --config - \
           "$BRAIN_URL/breath-hook" 2>/dev/null
)" || exit 0

# 只有空白 = 没记忆可注入，别往上下文里塞空壳
[ -n "${memories//[[:space:]]/}" ] || exit 0

# SessionStart 注入上下文的规范形式是 hookSpecificOutput.additionalContext。
# 用 python3 做 JSON 转义；万一镜像里没有 python3，退回裸文本（stdout 同样会被采纳）。
if command -v python3 >/dev/null 2>&1; then
  printf '%s' "$memories" | python3 -c 'import json,sys; print(json.dumps({"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":sys.stdin.read()}}, ensure_ascii=False))'
else
  printf '%s\n' "$memories"
fi
