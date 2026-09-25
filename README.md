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

代价是它不吭声——开场没带记忆的时候，你看不出来是哪一条。往下翻有排查顺序。

## 开场没带记忆？按这个顺序查

钩子是安静失败的，所以它不会告诉你哪儿错了。在会话里挨个打这几条，
第一条不对就停下，不用往后查：

```bash
echo "${OMBRE_BRAIN_URL:-<unset>}"                      # 1. 空的？钩子第一行就退了
curl -s -o /dev/null -w '%{http_code}\n' "$OMBRE_BRAIN_URL/health"       # 2. 大脑活着吗
curl -s -i "$OMBRE_BRAIN_URL/breath-hook" | head -20    # 3. 这一口通不通
```

第 2 步 200、第 3 步 401，就是鉴权没过。这时候**先确认大脑重新部署了没有**——

> ⚠️ 改了 `config.yaml` 的 `hooks.token` 但 Zeabur 没重新部署，线上跑的还是旧配置，
> token 怎么填都对不上。这种最难查，因为脚本和两边的配置看上去都是对的。
> 2026-09-25 排查了大半天，最后就是这个。

确认部署过了还是 401，再往下看这两处：

- **API credentials 的 value 填歪了**：多带了 `Bearer ` 前缀，或者复制粘贴时尾巴上跟了空格 / 换行；
- **头名对不上**：大脑只认 `x-ombre-hook-token`，而代理注的是 `Authorization: Bearer`。
  如果 credential 那栏允许自定义 header 名，直接把名字填成 `x-ombre-hook-token`、
  不选 Bearer、value 只放裸 token，两条路就走同一个头了。

改完环境变量或 credentials 都要**开新会话**才生效——当前窗口的环境是启动时定死的。
