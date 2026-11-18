# cc-usage-lite — 專案規則

## 入口與範圍

- 功能、安裝與限制見 `README.md`；本檔保存專案工作規則。
- 保持輕量：主腳本只讀 Claude Code 傳入的 stdin JSON，不掃描 transcripts、不連網、不加背景服務。

## 更新流程

- 沿用 Kelvin 個人 repo 的直接更新方式：預設在 `main` 修改、檢查、commit 並 push；Kelvin 明確要求分支或 PR 時依其指示。
- 修改前讀最新檔案與 `git status`，以局部修改為主；其他人或 AI 的未提交變更不得覆寫或混入提交。
- 腳本行為變動須補對應案例並執行 `./test.sh`；安裝與平台支援的宣稱須有實際驗證。純規則或文件修改檢查 diff 與格式即可。
- commit 前檢查 staged diff，只提交本次相關檔案；push 後若觸發 CI，確認結果再回報完成。
- `main` 是目前安裝命令的來源；更新須維持既有設定與使用方式相容，並同步修改受影響的 README 說明。

## 協作署名

- Codex 建立的每個 commit 都必須在訊息末尾加入以下 trailer，與正文隔一個空行：

  ```text
  Co-Authored-By: Codex <noreply@openai.com>
  ```

- 保留人類作者與其他實際協作者署名；若採用 squash merge，最終 commit 也須保留 Codex trailer。
- 此規則也適用於文件與規則更新；不替沒有參與的工具署名。
