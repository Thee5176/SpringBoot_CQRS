# SpringBoot_CQRS

## 目次
1. [インストールと実行手順](#インストールと実行手順)
2. [主な機能](#主な機能)
3. [開発原則](#開発原則)
4. [システム設計](#インストールと実行手順)
5. [新技術の導入（試行錯誤）](#新技術の導入（試行錯誤）)
6. [新しく学んだトピック（会議・フィードバック）](#新しく学んだトピック（会議・フィードバック）)

## インストールと実行手順
```bash
# 1. ディレクトリ準備 \& GitHubからクローン
git clone --recurse-submodules -j3 https://github.com/Thee5176/SpringBoot_CQRS
cd SpringBoot_CQRS

# 2. マイグレーションとビルド処理

## 2.1 コマンドユニット：Postgresコンテナ起動とDBセットアップ
docker compose up postgres -d --build
cd springboot_cqrs_command
chmod +x mvnw
./mvnw flyway:migrate
./mvnw clean package -DskipTests
cd ..

## 2.2 クエリユニット
cd springboot_cqrs_query
chmod +x mvnw
./mvnw clean package -DskipTests
cd ..

# 3. 全サービス起動
docker compose build --no-cache
docker compose up -d
```

## 主な機能

### SpringBoot コマンドサービス

| 機能 | 内容説明 | 参照リンク |
| :-- | :-- | :-- |
| カスタムオブジェクトマッパー | DTOと複数ドメインエンティティ間のフィールドマッピングをModelMapperでカスタマイズ | [ModelMapperConfig.java](https://github.com/Thee5176/SpringBoot_CQRS_Command/blob/develop/src/main/java/com/thee5176/ledger_command/Application/config/ModelMapperConfig.java) |
| 二重入力バリデーション | - BalanceCheck：balanceTypeごとのamountの合計がBigDecimal.ZEROと一致するかをカスタムバリデータで検証<br>- アカウントコード（COA）重複チェック：DTOメソッドとHibernate UniqueElementsによるチェック | - [BalanceCheckValidator.java](https://github.com/Thee5176/SpringBoot_CQRS_Command/blob/develop/src/main/java/com/thee5176/ledger_command/Application/validation/BalanceCheckValidator.java) <br> - [LedgersEntryDTO.javaのユニーク化](https://github.com/Thee5176/SpringBoot_CQRS_Command/blob/develop/src/main/java/com/thee5176/ledger_command/Application/dto/LedgersEntryDTO.java#L37) |
| トランザクション管理 | - 作成トランザクション：集約エンティティを含む作成処理<br>- 置換更新トランザクション：Java Streamを用いたアップサート処理 | - [作成トランザクション](https://github.com/Thee5176/SpringBoot_CQRS_Command/blob/develop/src/main/java/com/thee5176/ledger_command/Domain/service/LedgerCommandService.java#L33) <br> - [更新トランザクション](https://github.com/Thee5176/SpringBoot_CQRS_Command/blob/develop/src/main/java/com/thee5176/ledger_command/Domain/service/LedgerCommandService.java#L56) |

### トランザクション管理のシーケンス図

**作成トランザクション**
```mermaid
sequenceDiagram
        actor User
        participant Controller as LedgerController
        participant Service as LedgerCommandService
        participant Repo as LedgerRepository
        participant ItemRepo as LedgerItemsRepository
        participant Mapper as LedgerMapper
        participant ItemsMapper as LedgerItemsMapper

User->>Controller: POST /ledger (CreateLedgerDTO)
        Controller->>Service: createLedger(CreateLedgerDTO)
        Service->>Mapper: map(CreateLedgerDTO) → Ledgers
        Service->>Repo: createLedger(Ledgers)
        Service->>ItemsMapper: map(CreateLedgerDTO) → List<LedgerItems>
        loop for each LedgerItems
            Service->>ItemRepo: createLedgerItems(LedgerItems)
        end
        Service-->>Controller: (void)
        Controller-->>User: 200 OK / error
```
**置換更新トランザクション**
```mermaid
sequenceDiagram
        actor User
        participant Controller as LedgerController
        participant Service as LedgerCommandService
        participant Mapper as LedgerItemsMapper
        participant Repo as LedgerItemRepository

User->>Controller: POST /ledger (CreateLedgerDTO)
        Controller->>Service: updateLedger(LedgerEntryDTO)
        Service->>Repo: getLedgerItemsByLedgerId(ledgerEntryDTO.id)
        Service->>Mapper: map(ledgerEntryDTO)
        Service->>Service: Map existing items by COA
        Service->>Service: For each update item:
        alt COA exists
            Service->>Repo: updateLedgerItems(item)
        else COA does not exist
            Service->>Repo: createLedgerItems(item)
        end
        Service->>Service: For each existing item not in update list
        Service->>Repo: deleteLedgerItems(item.id)
```
### SpringBoot クエリサービス

| 機能 | 内容説明 | 参照リンク |
| :-- | :-- | :-- |
| JOOQによる結合クエリ | リポジトリ層でJOINクエリを用いてN+1問題を解消 | [LedgersRepository.java](https://github.com/Thee5176/springboot_cqrs_query/blob/develop/src/main/java/com/thee5176/ledger_query/Infrastructure/repository/LedgersRepository.java#L57) |
| 平坦化データ抽出 | サービス層でIDからエンティティへのMapを作成し、再帰的なクエリを排除（N+1問題への対策） | [LedgersQueryService.java](https://github.com/Thee5176/SpringBoot_CQRS_Query/blob/develop/src/main/java/com/thee5176/ledger_query/Domain/service/LedgersQueryService.java#L24) |

#### JOOQ結合クエリのシーケンス図
```mermaid
sequenceDiagram
        participant Service
        participant JOOQContext
        participant LedgersTable
        participant LedgerItemsTable

Service->>JOOQContext: fetchDtoContext()
        JOOQContext->>LedgersTable: from(Tables.LEDGERS)
        JOOQContext->>LedgerItemsTable: leftJoin(Tables.LEDGER_ITEMS)
        JOOQContext->>LedgerItemsTable: on(LEDGERS.ID = LEDGER_ITEMS.LEDGER_ID)
        JOOQContext->>LedgersTable: where(LEDGERS.ID = id)
        JOOQContext->>Service: fetchInto(LedgersQueryOutput.class)
        Service-->>Service: return List<LedgersQueryOutput>
```
#### 平坦化データ抽出トランザクションのシーケンス図
```mermaid
sequenceDiagram
        participant Controller
        participant LedgersRepository
        participant ModelMapper
        participant Logger

Controller->>LedgersRepository: getAllLedgersDTO()
        LedgersRepository-->>Controller: List<LedgersQueryOutput>
        Controller->>Logger: log.info(queryOutputs)
        Controller->>ModelMapper: map each LedgersQueryOutput to GetLedgerResponse
        ModelMapper-->>Controller: List<GetLedgerResponse>
        Controller->>ModelMapper: map and group by ledgerId to LedgerItemsAggregate
        ModelMapper-->>Controller: Map<ledgerId, List<LedgerItemsAggregate>>
        Controller->>Controller: setLedgerItems() for each GetLedgerResponse
        Controller-->>Controller: return List<GetLedgerResponse>
```
## フロントエンド React フォーム

| 機能 | 内容説明 | 参照リンク |
| :-- | :-- | :-- |
| 動的コンポーネント分割 | Atomic Designパターンに従い、複雑なコンポーネントをよりシンプルでメンテナンスしやすい部品に分割 |  |
| LedgerItemsの動的追加 | LedgerItemsの入力フィールドを動的に追加 | - [LedgerItemInputField.tsx](https://github.com/Thee5176/React_MUI_Accounting_CQRS/blob/develop/src/components/LedgerItemInputField/index.tsx)<br>- [LedgerItemsFormTable.tsx](https://github.com/Thee5176/React_MUI_Accounting_CQRS/blob/99129f8f92ce6f16994f2c5bc34de9fb2cbabeb6/src/components/LedgerItemsFormTable.tsx)<br> |
| COA選択フィールドの動的取得 | クエリサービスから「Code of Account」の選択肢を動的に取得 | [CoaField.tsx](https://github.com/Thee5176/React_MUI_Accounting_CQRS/blob/develop/src/components/LedgerItemInputField/CoaField.tsx)<br> |
| React Hook Form連携 | React Hook FormのuseFormフックでフォームの送信処理を管理 | [LedgerEntryForm.tsx](https://github.com/Thee5176/React_MUI_Accounting_CQRS/blob/develop/src/pages/LedgerEntryForm.tsx)<br>- [Confluence リポート](https://thee5176.atlassian.net/wiki/spaces/~7120207a78457b1be14d1eb093ee37135d9fb6/pages/68026372/React+MUI#3.-Form-handling-with-React-Hook-Form) |
| バリデーションとエラーメッセージ | 入力値の検証と送信前のエラー表示 |  |
| 再利用可能なバリデーション部品 | エラーメッセージのコンポーネントを集中管理 | [Error Message Component](https://github.com/Thee5176/React_MUI_Accounting_CQRS/blob/develop/src/components/ErrorAlert.tsx)<br> |

### バリデーション条件・エラーメッセージのシーケンス図
```mermaid
sequenceDiagram
        actor User
        participant LedgerEntryForm
        participant ErrorAlert

User->>LedgerEntryForm: フォーム入力・送信
        LedgerEntryForm->>LedgerEntryForm: 項目バリデーション（react-hook-form）
        alt バリデーション失敗
            LedgerEntryForm->>ErrorAlert: エラーメッセージ表示
        else バリデーション成功
            LedgerEntryForm->>LedgerEntryForm: バックエンドへ送信
            LedgerEntryForm->>LedgerEntryForm: フォームリセット
        end
```
# 開発原則

| ブランチ種別 | 派生元 | 用途 | マージタイミング | 備考 |
| :-- | :-- | :-- | :-- | :-- |
| main | — | 新機能のデプロイ用 | コードベースが安定・確認済み時のみマージ | デプロイ用ブランチ |
| develop | main | 複数機能の開発管理 | コードベースが安定・確認済み時のみマージ | 統合用ブランチ |
| feature | develop | ローカル開発・小まめなコミット | 制限なし、複数同時進行可能 | 複数機能ブランチ並行可能 |
| hotfix | main | バグ修正 | 修正完了後すぐマージ | 複数ホットフィックス可能 |

### 追加説明

- トップダウン開発アプローチを推奨（DB設計 → モジュール設計 → 実装）
- "[A successful Git branching model](https://nvie.com/posts/a-successful-git-branching-model/)"に基づいたGit運用
- 安定性を重視した明確なマージ戦略で並行開発を管理

---
## 実行手順
```bash
#1 ディレクトリ準備とGitHubからクローン
mkdir ledger_cqrs_unit
cd ledger_cqrs_unit
git clone https://github.com/Thee5176/springboot_cqrs_command springboot_cqrs_command
git clone https://github.com/Thee5176/springboot_cqrs_query springboot_cqrs_query

#2 マイグレーション・ビルドプロセス

##2.1 コマンドユニット：Postgresコンテナ起動とDBセットアップ
docker compose up postgres -d --build
cd springboot_cqrs_command
chmod +x mvnw
./mvnw flyway:migrate
./mvnw clean package -DskipTests
cd ..

##2.2 クエリユニット：
cd springboot_cqrs_query
chmod +x mvnw
./mvnw clean package -DskipTests
cd ..

#3 全サービス起動
docker compose build --no-cache
docker compose up -d
```
---
## 新技術の導入（試行錯誤）
- Git Flow, Git Pull Request, Git Issues, Git Submodule
    - ベストプラクティスに従ったローカルブランチ管理 [GitFlow]
    - マージ前の変更レビュー [Git Pull Request](https://github.com/pulls?q=is%3Apr+author%3AThee5176+archived%3Afalse+repository%3Bspringboot*)
    - 個別履歴管理のための集約プロジェクト [Git Submodule](https://github.com/Thee5176/SpringBoot_CQRS/tree/main)
    - 参考: [Git実践入門](https://gihyo.jp/book/2014/978-4-7741-6366-6)

- Github Workflow
    - 継続的インテグレーションによるビルド検証
    - [コマンドユニットワークフロー](https://github.com/Thee5176/springboot_cqrs_command/actions/workflows/testrun.yaml)
    - [クエリユニットビルドワークフロー](https://github.com/Thee5176/springboot_cqrs_query/actions/workflows/testrun.yaml)
    - [デプロイメントワークフロー](https://github.com/Thee5176/SpringBoot_CQRS/actions/workflows/testrun.yaml)

- Sourcery.ai - プルリクエストレビューサービス
    - AIによる変更レビューガイドライン
    - コード提案作成例 [PRレビュー例](https://github.com/Thee5176/springboot_cqrs_command/pull/9#issuecomment-3092684740)
    - 参考: [Sourcery AI](https://sourcery.ai/)

- Flyway 
    - [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L162)でFlyway DBマイグレーションサービス設定
    - DBバージョン管理 [source/main/resources/db/migrations](https://github.com/Thee5176/springboot_cqrs_command/tree/develop/src/main/resources/db/migration)
    - 参考: [Spring Doc](https://docs.spring.io/spring-boot/how-to/data-initialization.html#howto.data-initialization.migration-tool.flyway)

- JOOQ
    - JOOQ Codegenによるトップダウン開発
        - dbml言語でDB設計 [DB設計ドキュメント](https://dbdocs.io/theerapong5176/Springboot_CQRS?view=relationships)
        - [dbdiagram.io](https://dbdiagram.io/)でDDLスクリプト生成
        - JOOQ Codegen依存関係設定 [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L175)
        - 参考: [JOOQ Document](https://www.jooq.org/doc/latest/manual/code-generation/codegen-execution/codegen-maven/)

- ModelMapper
    - [pom.xml](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/pom.xml#L78)でModelMapper設定
    - カスタムDTO設定 [ModelMapperConfig](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/main/java/com/thee5176/ledger_command/Application/config/ModelMapperConfig.java)
    - 参考: [ModelMapper Document](https://modelmapper.org/getting-started/)
 
- Arrange-Action-Assert テストプロセス:
    1. Arrange - テストデータ準備
    2. Action - テスト対象実行
    3. Assert - 期待動作の検証
  
    
- ユニットテストと統合テスト
  - **ユニットテスト** - 各内部コードコンポーネントの出力検証 [JUnit](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/test/java/com/thee5176/ledger_command/Application/dto/LedgersEntryTest.java)
  - **統合テスト** - 他関数の統合呼び出しと出力モック [Mockito](https://github.com/Thee5176/springboot_cqrs_command/blob/develop/src/test/java/com/thee5176/ledger_command/Domain/service/LedgerCommandServiceTest.java)
  
- [Docker マージComposeファイル](https://github.com/Thee5176/SpringBoot_CQRS/blob/main/compose.yaml)

---
## 新しく学んだトピック（会議・フィードバック）
- マイクロサービス vs モノリスアーキテクチャ
    - **比較表：**
        | 特徴               | モノリス                                       | マイクロサービス                                     |
        |---------------------|------------------------------------------------|--------------------------------------------------|
        | **パフォーマンス**     | プロセス内直接呼び出しで高速な場合がある。         | サービス間のネットワーク遅延で低速。                |
        | **リソース**        | オーバーヘッド少、単一デプロイメントユニット。     | オーバーヘッド多、各サービスが独立したリソース必要。 |
        | **共同開発**        | 密結合で大規模チームの並行作業が困難。             | 疎結合で独立したチーム作業が容易。                  |
        | **開発速度**        | 初期は速いがコードベース拡大で遅くなる。           | 初期は遅いがシステム拡張で速度維持。                |

- UUID/ULID/IntegerのDB主キー利用
    - **比較表：**
        | key_type | bit数    | キー数            | 順序     | ランダム性        |
        |----------|-----------|-------------------|-----------|-------------------|
        | UUID v7  | 128-bit   | ~3.4 x 10^38      | あり      | 高（74ビット）    |
        | UUID v4  | 128-bit   | ~3.4 x 10^38      | なし      | 高（122ビット）   |
        | ULID     | 128-bit   | ~3.4 x 10^38      | あり      | 高（80ビット）    |
        | Integer  | 32-bit    | ~43億             | あり      | なし              |
    - **状況別利用：**
        - **Integer/BigInt**: 単純な単一DBアプリ向け。グローバル一意性不要。小さく高速で人間可読。
        - **UUID v4**: 分散システムで一意性必要だが順序不要。高ランダム性で推測困難。DBインデックス断片化の可能性。
        - **ULID/UUID v7**: 一意性と時系列順序が必要な分散システム向け。インデックス断片化防止で挿入性能向上。UUID v7は最新標準。
    - **決定フローチャート：**
```mermaid
graph TD
    A[主キー選択開始] --> B{グローバル一意ID必要?}
    B -- No --> C[Integer/BigIntを使用]
    B -- Yes --> D{性能/順序のため時系列キー必要?}
    D -- No --> E[UUID v4を使用]
    D -- Yes --> F[UUID v7またはULIDを使用]
```

- ユビキタス言語とエンティティ名リファクタリング
    - 予約語、開発用語
    - コツ：マスター・トランザクションエンティティ、具体的な言語使用

- バリデーションチェーン
    - フロントエンド → DTOバリデーション → ... → DBバリデーション
    - 各層で同じロジックを検証するのは冗長に見えるが、データフロー品質向上に有効
    - 早期バリデーションで例外発生を最小化し、スループットとシステム負荷を改善

- マスターデータ管理アプローチ
    - **Enum**
        - 長所：インメモリ保存（DBクエリより高速）、一貫性保証（ユーザー側で変更不可）
        - 短所：静的ハードコード（変更はソース編集必要）

    - **マスターエンティティ（テーブル）**
        - 長所：動的データ保存（ユーザー側で変更可能）
        - 短所：一貫性問題（クエリでデータ操作可能）

# アジャイル vs ウォーターフォール開発手法

## 比較表: アジャイル vs. ウォーターフォール

| **項目**              | **アジャイル**                                                                 | **ウォーターフォール**                                                            |
|-------------------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------|
| **チーム構成**      | フラットで協力的、全員がアイデアを出す。                          | 階層型、リーダーがスキルに応じてタスク割り当て。         |
| **計画手法**   | 最小限の事前計画、スプリント中に進化。                         | 事前計画が多く、固定フェーズ。                            |
| **ワークフロー**            | イテレーティブかつインクリメンタル（短いスプリント）。                                | 順次フェーズ（要件→設計→実装→テスト）。    |
| **柔軟性**         | 要件変更に高い適応性。                                | 固定的、計画後の変更は高コスト。                    |
| **ドキュメント**       | 軽量、動作するソフト重視。              | 重厚なドキュメントと設計仕様が必要。                  |
| **スキル依存**    | メンバーのスキルが均等な場合に最適。                   | 明確なリーダーシップで混在スキルに対応。               |
| **納品**            | 小さな機能単位を早期・頻繁に納品。                    | プロジェクト終了時に全体納品。         |
| **テスト**             | 各スプリントで継続的テスト。                           | 実装後にテスト。                               |
| **顧客フィードバック**   | 各スプリント・イテレーション終了時に頻繁。                         | 最終段階まで限定的。                      |
| **適合プロジェクト**     | 要件が変化する動的プロジェクト。                              | 要件が明確で安定したプロジェクト。                      |

---

 ## チーム構成とコラボレーション  
    
 ### **アジャイル**
    アジャイル開発は**フラットな組織構造**で、全員が積極的にアイデアを出すことを推奨します。各自が自律的にタスクを進め、**短いスプリント**（定期的な作業期間）で協力します。スプリント終了時に進捗共有・フィードバック・次サイクルへの適応を行います。
 - **利点：**
      - 全員がアイデアを出しやすく、創造性・革新性が高まる。
      - 迅速なフィードバックで継続的改善。
      - チームのプロジェクト所有感向上。
   
  - **課題：**
  - **スキル差が大きいと効率低下。** 技術力に差があると情報共有頻度が高まり進捗が遅れる場合がある。
  - 定期的な会議・レビューの時間コストが高い。
    
   ---
    
   ### **ウォーターフォール**
   ウォーターフォール開発は**階層型構造**で、技術力に差がある場合に適しています。経験豊富なリーダーやアーキテクトが設計を行い、スキルに応じてタスクを割り当て、指導します。
   
   - **利点：**
      - 明確なリーダーシップで意思決定が構造化。
      - 技術力が低いメンバーの混乱を防止。
      - 役割・責任が明確で作業重複を防ぐ。
    
   - **課題：**
      - 下位メンバーが初期段階でアイデアを出す機会が少ない。
      - 開発途中で要件変更があると柔軟性に欠ける。

---

## プロジェクトライフサイクル管理（PLCM）

### **ウォーターフォール**
ウォーターフォールは**事前計画が徹底**されています。要件定義、設計、実装、テスト、デプロイメントの各フェーズを順次実施。ドキュメント・設計は初期に作成され、**Vモデル**に従うことが多い：
- **Vモデル概要：** 開発各段階（Vの左側）に対応するテスト段階（右側）がある。例：要件は受入テスト、設計はシステムテストで検証。

**長所：**
- 予測可能な納期・成果物。
- 明確なドキュメントでトレーサビリティ確保。
- 要件が固定されたプロジェクトに最適。

**短所：**
- 要件変更に不向き。
- テストが後半になるため重大な問題発見が遅れる。
- コーディング前の計画に多くの時間が必要。

---

### **アジャイル**
アジャイルPLCMは**イテレーティブかつインクリメンタル**です。すべてを事前計画せず、**スプリント**（通常1～4週間）で進化。各スプリント終了時に出荷可能な成果物を納品し、フィードバックを次サイクルに反映。

**代表的なアジャイルプラクティス：**
- **スクラム：** 定義された役割（プロダクトオーナー、スクラムマスター、開発チーム）と定期的なスプリントレビュー・振り返り。
- **カンバン：** WIP（作業中）制限付きの可視化ボード。
- **CI/CD：** 頻繁な統合と自動デプロイ。

**長所：**
- 要件変更に迅速対応。
- インクリメンタルリリースで早期価値提供。
- コラボレーションと顧客参加を促進。

**短所：**
- 事前ドキュメント不足で長期保守に課題。
- 高い規律とコミュニケーションが必要。
- 厳格なコンプライアンスや固定予算プロジェクトには不向き。

---
