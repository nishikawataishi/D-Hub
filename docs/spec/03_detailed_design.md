# 詳細設計書: D.scout

## 1. データベース設計 (ERD)

### 1.1 テーブル定義

#### `users` (学生)
*   `id`: UUID (PK)
*   `email`: String (Unique, @doshisha.ac.jp 制限)
*   `name`: String
*   `faculty`: String (学部)
*   `grade`: Integer (学年)
*   `main_campus`: Enum (IMADEGAWA, KYOTANABE)
*   `avatar_url`: String
*   `bio`: Text

#### `organizations` (団体)
*   `id`: UUID (PK)
*   `name`: String
*   `description`: Text
*   `category`: Enum (SPORTS, CULTURE, ACADEMIC, etc.)
*   `campus`: Enum (IMADEGAWA, KYOTANABE, BOTH)
*   `logo_url`: String
*   `main_image_url`: String
*   `instagram_url`: String

#### `scouts` (スカウト)
*   `id`: UUID (PK)
*   `user_id`: FK(users.id)
*   `organization_id`: FK(organizations.id)
*   `message`: Text
*   `status`: Enum (PENDING, APPROVED, REJECTED)
*   `created_at`: Datetime

#### `events` (イベント)
*   `id`: UUID (PK)
*   `organization_id`: FK(organizations.id)
*   `title`: String
*   `description`: Text
*   `start_at`: Datetime
*   `end_at`: Datetime
*   `campus`: Enum (IMADEGAWA, KYOTANABE, BOTH)

#### `tags` (興味関心)
*   `id`: UUID (PK)
*   `name`: String (Unique)

#### `user_tags` (中間テーブル)
*   `user_id`: FK(users.id)
*   `tag_id`: FK(tags.id)

## 2. API設計 (主要エンドポイント)

| Method | Endpoint | Description |
| :--- | :--- | :--- |
| POST | `/api/v1/auth/login` | 同志社ドメインチェックを含む認証 |
| GET | `/api/v1/organizations` | インクリメンタル検索 & カテゴリフィルタ |
| GET | `/api/v1/scouts` | ユーザー宛のスカウト一覧取得 |
| PATCH | `/api/v1/scouts/{id}/approve` | スカウトの承認アクション |
| GET | `/api/v1/events` | 日付別イベント一覧 |
| POST | `/api/v1/me/tags` | 興味タグの追加（マイページ用） |
| DELETE | `/api/v1/me/tags/{id}` | 興味タグの削除（マイページ用） |

## 3. UIコンポーネント設計 (Flutter)
*   **BaseLayout**: `max-w-md` を実現するためのスクリーンスキャフォールド。
*   **OrganizationCard**: ホームで使用。画像、キャンパスバッジ、ロゴを内包。
*   **ScoutTile**: 時系列リスト用。未読バッジ付与ロジック込み。
*   **InterestTagEdit**: Wrapウィジェットを使用したタグの追加・削除インタラクション。
*   **CampusLabel**: 紫/緑/青のカラーテーマを統一するクラス。
