# Lambda画像リサイズサービス

AWS LambdaとS3を使用した画像自動リサイズサービスです。

## 📋 目次

1. [概要](#概要)
2. [アーキテクチャ](#アーキテクチャ)


## 概要

S3バケットに画像がアップロードされると、自動的に以下の3サイズにリサイズします：

- **small**: 200x200px（サムネイル）
- **medium**: 800x800px（中サイズ）
- **large**: 1200x1200px（大サイズ）

リサイズ済み画像は `resized/` フォルダに保存されます。

## アーキテクチャ

```
S3 (images/) → Lambda関数 → S3 (resized/)
```

1. ユーザーがS3の `images/` フォルダに画像をアップロード
2. S3イベント通知がLambda関数をトリガー
3. Lambda関数が画像をダウンロードしてリサイズ
4. リサイズ済み画像を `resized/` フォルダに保存

## 通信と処理の流れ（詳細図）

```mermaid
sequenceDiagram
    participant User as ユーザー
    participant S3Images as S3バケット<br/>(images/)
    participant S3Event as S3イベント通知
    participant Lambda as AWS Lambda<br/>サービス
    participant Handler as lambda_function.rb<br/>(lambda_handler)
    participant S3Resized as S3バケット<br/>(resized/)

    Note over User,S3Images: 【ステップ1: トリガー】
    User->>S3Images: 1. 画像をアップロード<br/>(例: photo.jpg)
    S3Images-->>S3Images: 画像が保存される

    Note over S3Images,Lambda: 【ステップ2-3: イベント通知とLambda起動】
    S3Images->>S3Event: 2. 画像アップロードを検知
    S3Event->>Lambda: 3. イベント通知を送信
    Lambda->>Handler: 4. lambda_handler を呼び出し<br/>event: S3イベント情報（JSON）<br/>context: Lambda実行コンテキスト

    Note over Handler: 【ステップ4-5: イベント解析】
    Handler->>Handler: 5. extract_s3_event(event)<br/>バケット名: "my-bucket"<br/>オブジェクトキー: "images/photo.jpg"

    Note over Handler,S3Images: 【ステップ6-7: 画像ダウンロード】
    Handler->>Handler: 6. process_image() を呼び出し
    Handler->>S3Images: 7. download_image()<br/>AWS SDK for S3 を使用
    S3Images-->>Handler: 8. 画像データを返す<br/>(バイナリデータ)

    Note over Handler: 【ステップ8-9: 画像リサイズ】
    Handler->>Handler: 9. resize_image()<br/>MiniMagickでリサイズ<br/>- small: 200x200<br/>- medium: 800x800<br/>- large: 1200x1200

    Note over Handler,S3Resized: 【ステップ10: リサイズ済み画像をアップロード】
    loop 各サイズ (small, medium, large)
        Handler->>S3Resized: 10. upload_resized_image()<br/>AWS SDK for S3 を使用
        S3Resized-->>S3Resized: リサイズ済み画像を保存<br/>resized/small/photo.jpg<br/>resized/medium/photo.jpg<br/>resized/large/photo.jpg
    end

    Note over Handler,Lambda: 【ステップ11: 処理完了】
    Handler->>Handler: 11. success_response() を返す
    Handler-->>Lambda: 12. 実行結果を返す<br/>{ statusCode: 200, body: "完了" }
    Lambda-->>S3Event: 13. 処理完了通知
```

## コスト見積もり

- **Lambda**: 100万リクエスト/月まで無料
- **S3**: 5GB保存で約150円/月
- **CloudWatch Logs**: 5GBまで無料

**合計**: 月200-500円程度（小規模利用の場合）

## 参考資料

- [AWS Lambda Ruby ランタイム](https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html)
- [MiniMagick ドキュメント](https://github.com/minimagick/minimagick)
