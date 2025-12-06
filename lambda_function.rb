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
    
    process_image(bucket_name, object_key)
    
    success_response("画像のリサイズが完了しました")
  rescue StandardError => e
    puts "エラーが発生しました: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n")
    error_response("エラー: #{e.message}")
  end
end

private

# MEMO: S3イベントから必要な情報を抽出
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
  raise "S3 Recordsが存在しません" if event['Records'].nil? || event['Records'].empty?
  
  record = event['Records'][0]

  raise "S3 Recordが存在しません" if record.nil?
  raise "S3 Record.S3 が存在しません" if record['s3'].nil?
  raise "S3 Record.S3.Bucket が存在しません" if record['s3']['bucket'].nil?
  raise "S3 Record.S3.Object が存在しません" if record['s3']['object'].nil?
  
  bucket_name = record['s3']['bucket']['name']
  object_key = record['s3']['object']['key']
  
  # オブジェクトキーをURLデコード
  require 'uri'
  decoded_key = URI.decode_www_form_component(object_key)
  
  #TODO: 一旦、ハッシュを返す。後で調整する。
  { bucket: bucket_name, key: decoded_key }
end

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
  
  sizes.each do |size_name, size_info|
    resized_image = resize_image(image_data, size_info[:width], size_info[:height])
    upload_resized_image(s3_client, bucket_name, object_key, size_name, resized_image)
    puts "#{size_name}サイズのリサイズが完了"
  end
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
