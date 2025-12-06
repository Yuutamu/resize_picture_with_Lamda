# frozen_string_literal: true

require 'json'
require 'aws-sdk-s3'
require 'mini_magick'

# NOTE: Lambda関数のエントリーポイント, S3からのイベントを受け取ると実行される
def lambda_handler(event:, context:)
  puts "イベントを受信しました: #{event.to_json}"

  begin
    # TODO: S3イベントから情報を抽出する関数
    s3_event = extract_s3_event(event)
    
    bucket_name = s3_event[:bucket]
    object_key = s3_event[:key]
    
    if object_key.include?("resized/")
      puts "リサイズ済み画像のためスキップ: #{object_key}"
      return success_response("スキップしました")
    end
    
    # TODO: 画像を処理する関数を呼び出す
    process_image(bucket_name, object_key)
    
    success_response("画像のリサイズが完了しました")
  rescue StandardError => e
    puts "エラーが発生しました: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n")
    error_response("エラー: #{e.message}")
  end
end

private

# S3イベントから必要な情報を抽出
# 
# 【処理内容】
# - event['Records'] の最初の要素を取得
# - s3 データからバケット名とオブジェクトキーを取得
# - オブジェクトキーはURLエンコードされているのでデコードする
# - { bucket: "バケット名", key: "オブジェクトキー" } のハッシュを返す
#
# 【S3イベントの構造例】
# {
#   "Records": [
#     {
#       "s3": {
#         "bucket": { "name": "my-bucket" },
#         "object": { "key": "images/photo.jpg" }
#       }
#     }
#   ]
# }
def extract_s3_event(event)
  # TODO: S3イベントから情報を抽出する
end

# 画像を処理するメイン関数
# 
# 【処理内容】
# 1. S3クライアントを作成
# 2. S3から画像をダウンロード
# 3. 3つのサイズ（small, medium, large）にリサイズ
# 4. リサイズ済み画像をS3にアップロード
#
# 【リサイズサイズ】
# - small: 200x200px
# - medium: 800x800px
# - large: 1200x1200px
def process_image(bucket_name, object_key)
  puts "画像を処理中"
  
  s3_client = Aws::S3::Client.new
  
  image_data = download_image(s3_client, bucket_name, object_key)
  
  sizes = {
    small: { width: 200, height: 200 },
    medium: { width: 800, height: 800 },
    large: { width: 1200, height: 1200 }
  }
  
  # TODO: 各サイズに対してループ処理
  #   - 画像をリサイズ
  #   - リサイズ済み画像をS3にアップロード
  #   - ログ：「XXサイズのリサイズが完了」
end

def download_image(s3_client, bucket_name, object_key)

  puts "画像をダウンロード中"
  # NOTE: S3からオブジェクトを取得 get_object AWS SDK for Ruby のメソッド
  response = s3_client.get_object(bucket: bucket_name, key: object_key)

  return response.body.read
end


def resize_image(image_data, width, height)
  puts "画像をリサイズ中: #{width}x#{height}"
  # TODO:画像をリサイズ する処理を書く
end

def upload_resized_image(s3_client, bucket_name, original_key, size_name, image_data)
  # TODO:リサイズ済み画像をS3にアップロード する処理を書く
end

def success_response(message)
  # TODO: statusCode を一旦デバッグ用に用意しておく
  {
    statusCode: 200,
    body: JSON.generate({ message: message })
  }
end

def error_response(message)
  # TODO: statusCode を一旦デバッグ用に用意しておく
  {
    statusCode: 500,
    body: JSON.generate({ error: message })
  }
end
