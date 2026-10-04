# DeepSeekBalance · DeepSeek 余额

一个 iOS 小应用：填入自己的 DeepSeek API Key，随时查看账户余额（总余额 / 充值余额 / 赠送余额 / 账户可用状态）。

- 余额数据来自 DeepSeek 官方接口 `GET https://api.deepseek.com/user/balance`。
- API Key 只保存在本机 Keychain，只会发送到 `api.deepseek.com`。

## 怎么构建和测试

本仓库用 [ios-ci-workflows](https://github.com/wenjinliuu/ios-ci-workflows) 在 GitHub Actions 上编译、测试、发布 TestFlight；本地不跑 Xcode，CI 是唯一测试入口。
工程文件由 XcodeGen 从 `project.yml` 生成（`xcodegen generate`）。

- 配置：`.ios-ci.yml`
- 工作流入口：`.github/workflows/`（含自定义的 **Unsigned IPA**：手动运行可产出不签名 IPA，配合 AltStore / Sideloadly / 轻松签 等自签工具安装）
- AI 协作规则：`AGENTS.md`

## 结构

```
DeepSeekBalance/       App 源码（SwiftUI）
DeepSeekBalanceTests/  逻辑测试（Swift Testing）
DesignAssets/AppIcon/  图标素材与生成来源
```
