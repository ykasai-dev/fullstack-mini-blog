import { Injectable } from '@nestjs/common';
import {
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'node:crypto';

@Injectable()
export class StorageService {
  // 認証情報は書かない。AWS_PROFILE（ローカル）やタスクロール（AWS）から自動で取得する
  private readonly s3 = new S3Client({
    region: process.env.AWS_REGION,
    // チェックサムを、必要なときだけ付ける
    // （初期値のままだと、署名付き URL にチェックサムが含まれ、ブラウザからの PUT が失敗する）
    requestChecksumCalculation: 'WHEN_REQUIRED',
  });
  private readonly bucket = process.env.S3_BUCKET ?? '';

  // アップロード用の URL と、保存先のキーを返す
  // URL を作るときは S3 と通信しない（手元で署名を計算するだけ）
  async createUploadUrl(contentType: string) {
    const key = `posts/${randomUUID()}`; // ファイル名はサーバーで決める（利用者には決めさせない）
    const uploadUrl = await getSignedUrl(
      this.s3,
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        ContentType: contentType, // PUT するときの Content-Type が、これと違うと 403
      }),
      { expiresIn: 300 }, // 有効期限 5分（期限内なら何度でも使える）
    );
    return { uploadUrl, key };
  }

  // 表示用の URL を返す
  createDownloadUrl(key: string): Promise<string> {
    return getSignedUrl(
      this.s3,
      new GetObjectCommand({ Bucket: this.bucket, Key: key }),
      { expiresIn: 3600 }, // 有効期限 1時間
    );
  }
}
