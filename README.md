# ScaleMe 网站

观我（ScaleMe）的公开产品网站，包含产品介绍、技术支持和隐私政策页面。

网站与 iOS 应用统一维护在 `bugwz/ScaleMe` 仓库：应用位于 `main` 分支，网站位于 `web` 分支。网站保留独立目录结构，不需要构建依赖。

## 发布

在仓库 Settings → Pages 中选择 `Deploy from a branch`，分支选择 `web`，目录选择 `/ (root)`。推送到 `web` 后由 GitHub Pages 自动发布。

自定义域名为 `scaleme.bugwz.com`，由根目录 `CNAME` 文件与 Pages 设置共同维护。请勿启用旧仓库的部署流程。

- 首页：`index.html`
- 技术支持：`support.html`
- 隐私政策：`privacy.html`
- 页面配图：`assets/screenshot-dashboard.jpg`、`assets/screenshot-trends.jpg`

仅保留网页实际引用的资源；不在此分支保存多语言商店截图或源图片归档。
