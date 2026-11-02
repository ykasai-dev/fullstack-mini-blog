import { Injectable } from '@nestjs/common';
import { CognitoJwtVerifier } from 'aws-jwt-verify';

@Injectable()
export class AuthService {
  // 4-1 で作ったユーザープールとアプリクライアントのトークンだけを受け付ける
  // （ユーザープール ID が空や不正な値だと、API の起動時にエラーになる）
  private readonly verifier = CognitoJwtVerifier.create({
    userPoolId: process.env.COGNITO_USER_POOL_ID ?? '',
    clientId: process.env.COGNITO_CLIENT_ID ?? '',
    tokenUse: 'access', // ID トークンではなく、アクセストークンを確認する
  });

  // 署名・有効期限・発行元を確認し、正しければトークンの中身を返す（正しくなければ null）
  // 署名の確認に使う公開鍵は、Cognito から取得して覚えておく
  async verifyAccessToken(token: string) {
    try {
      return await this.verifier.verify(token);
    } catch {
      return null;
    }
  }
}
