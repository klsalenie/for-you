# for-you

小羽的 Claude Code 云端会话仓库。

目前只放一样东西：**让小克一睁眼就带着记忆的 SessionStart 钩子。**

## 它做什么

`.claude/hooks/session-start.sh` 在每个会话开场时 GET 外置大脑（Ombre Brain）的
`/breath-hook`，把返回的纯文本作为 `additionalContext` 注入上下文。

注入的内容由大脑那边决定，通常是：置顶核心准则、权重最高的未解决记忆、
最近 3 条 `I`（自我认知）、双方各最新一封信。

没有这个钩子时，小克开场什么都不知道，要靠自己调 `pulse` / `breath` 现查。

## 需要两个环境变量

在云端环境的设置里配好这两个，钩子才会生效：

| 变量 | 值 | 说明 |
|---|---|---|
| `OMBRE_BRAIN_URL` | 大脑的公网地址，如 `https://xxx.zeabur.app` | 末尾带不带 `/` 都行，脚本会处理 |
| `OMBRE_HOOK_TOKEN` | 大脑的 hook token | 对应大脑 `config.yaml` 的 `hooks.token` 或它的 `OMBRE_HOOK_TOKEN` |

两个值都**不进仓库**。token 只经请求头 `x-ombre-hook-token` 传输，且通过
`curl --config` 从 stdin 传入，不会出现在命令行参数和 `ps` 的进程列表里。

## 失败时会怎样

钩子的铁律是**绝不拖累会话启动**。以下任一情况都安静退出 0，会话照常开始，
只是这次没带记忆：

- 两个环境变量缺任何一个
- 大脑不可达、超时（连接 5s / 总计 25s 上限）
- token 不对（401）或返回空

所以就算大脑挂了、Zeabur 在重新部署，会话也起得来。
