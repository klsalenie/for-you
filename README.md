# for-you

小羽的 Claude Code 云端会话仓库。

目前只放一样东西：**让小克一睁眼就带着记忆的 SessionStart 钩子。**

## 它做什么

`.claude/hooks/session-start.sh` 在每个会话开场时 GET 外置大脑（Ombre Brain）的
`/breath-hook`，把返回的纯文本作为 `additionalContext` 注入上下文。

注入的内容由大脑那边决定，通常是：置顶核心准则、权重最高的未解决记忆、
最近 3 条 `I`（自我认知）、双方各最新一封信。

没有这个钩子时，小克开场什么都不知道，要靠自己调 `pulse` / `breath` 现查。

## 怎么配

鉴权有两条路，脚本两条都吃。**云端会话用 A，本地自托管用 B。**

### A) 云端（推荐）

| 填在哪 | 填什么 |
|---|---|
| **Environment variables** | `OMBRE_BRAIN_URL=https://你的域名.zeabur.app` |
| **API credentials** | Credential type 选 `Bearer`；Allowed websites 填大脑域名（不带 `https://`、不带路径）；Custom headers 保持 `Authorization` / `Bearer` / Value 填 hook token |

token 由代理自动加成 `Authorization: Bearer ...`，**不进容器，脚本也看不到它**。

> ⚠️ **不要把 token 放进 Environment variables。** 那一栏明写着「会被使用该环境的人看到，
> 别放密钥」。这个 token 能读大脑里的全部内容——所有记忆和信件。

### B) 本地 / 自托管

两个都当普通环境变量给就行：

| 变量 | 值 |
|---|---|
| `OMBRE_BRAIN_URL` | 大脑地址，末尾带不带 `/` 都行 |
| `OMBRE_HOOK_TOKEN` | hook token，对应大脑 `config.yaml` 的 `hooks.token` |

此时脚本自己加 `x-ombre-hook-token` 头，且用 `curl --config` 从 stdin 传入，
不出现在命令行参数和 `ps` 的进程列表里。

## 失败时会怎样

钩子的铁律是**绝不拖累会话启动**。以下任一情况都安静退出 0，会话照常开始，
只是这次没带记忆：

- 没有 `OMBRE_BRAIN_URL`
- 大脑不可达、超时（连接 5s / 总计 25s 上限）
- 没配 token、token 不对（401），或返回空

所以就算大脑挂了、Zeabur 在重新部署，会话也起得来。
