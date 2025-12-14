# frozen_string_literal: true

require "json"
require "uri"
require "aws-sdk-s3"
require "mini_magick"

# NOTE: Lambda関数のエントリーポイント, S3からのイベントを受け取ると実行される
# NOTE: context はLambda実行環境の情報（実行時間、メモリなど） で、今回は使用しない
def lambda_handler(event:, context: nil)
  puts "イベントを受信しました: #{event.to_json}"

  begin
    s3_event = extract_s3_event(event)
    
    bucket_name = s3_event[:bucket]
    object_key = s3_event[:key]
    aws_region = s3_event[:region]
    
    if object_key.include?("resized/")
      puts "リサイズ済み画像のためスキップ: #{object_key}"
      return success_response("スキップしました")
    end
    
    process_image(bucket_name, object_key, aws_region)
    
    success_response("画像のリサイズが完了しました")
  rescue StandardError => e
    puts "エラーが発生しました: #{e.class} - #{e.message}"
    puts e.backtrace.join("\n")
    error_response("エラー: #{e.message}")
  end
end

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
  raise "S3 Recordsが存在しません" if event["Records"].nil? || event["Records"].empty?
  
  record = event["Records"][0]

  raise "S3 Recordが存在しません" if record.nil?
  raise "S3 Record.S3 が存在しません" if record["s3"].nil?
  raise "S3 Record.S3.Bucket が存在しません" if record["s3"]["bucket"].nil?
  raise "S3 Record.S3.Object が存在しません" if record["s3"]["object"].nil?
  
  bucket_name = record["s3"]["bucket"]["name"]
  object_key = record["s3"]["object"]["key"]
  aws_region = record["awsRegion"] || ENV["AWS_REGION"] || "ap-northeast-1"
  
  # オブジェクトキーをURLデコード
  decoded_key = URI.decode_www_form_component(object_key)
  
  { bucket: bucket_name, key: decoded_key, region: aws_region }
end

# 【リサイズサイズ】
# - small: 200x200px
# - medium: 800x800px
# - large: 1200x1200px
def process_image(bucket_name, object_key, aws_region = nil)
  puts "画像を処理中"
  
  s3_client = Aws::S3::Client.new(region: aws_region || ENV["AWS_REGION"] || "ap-northeast-1")
  
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

  response.body.read
end

# MiniMagick のメソッドのドキュメントを参照 : https://www.rubydoc.info/gems/rmagick/Magick/Image#resize-instance_method:~:text=of%20the%20receiver.-,%23resize(cols%2C%20rows%2C%20filter%2C%20blur)%20%E2%87%92%20Magick%3A%3AImage,-Parameters%3A
# 画像データから画像オブジェクトを作成し、最終的にバイナリデータに変換して返す
def resize_image(image_data, width, height)
  puts "画像をリサイズ中: #{width}x#{height}"
  
  image = MiniMagick::Image.read(image_data)
  image.resize "#{width}x#{height}^"
  image.to_blob
end

def upload_resized_image(s3_client, bucket_name, original_key, size_name, image_data)
  puts "リサイズ済み画像をアップロード中: #{size_name}"
  
  # 元のキーからファイル名を抽出
  # 例: "images/photo.jpg" → "photo.jpg"
  filename = File.basename(original_key)
  
  # リサイズ済み画像のキーを生成
  # 例: "resized/small/photo.jpg"
  resized_key = "resized/#{size_name}/#{filename}"
  
  # 元のキーから拡張子を取得してContent-Typeを決定
  content_type = determine_content_type(original_key)
  
  # S3にアップロード
  s3_client.put_object(
    bucket: bucket_name,
    key: resized_key,
    body: image_data,
    content_type: content_type
  )
  
  puts "アップロード完了: #{resized_key}"
end

# ファイル拡張子からContent-Typeを決定
def determine_content_type(key)
  case File.extname(key).downcase
  when ".png"
    "image/png"
  else
    # .jpg, .jpeg およびその他の拡張子は image/jpeg を返す
    "image/jpeg"
  end
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
