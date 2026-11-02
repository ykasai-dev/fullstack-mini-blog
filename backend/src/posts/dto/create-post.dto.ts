import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';
import { PostStatus } from '../../generated/prisma/client.js';

export class CreatePostDto {
  @IsString()
  @IsNotEmpty() // 空の文字列は 400 にする
  title: string;

  @IsString()
  @IsNotEmpty()
  body: string;

  @IsOptional() // 省略してよい（省略すると、データベースの初期値 draft になる）
  @IsEnum(PostStatus) // draft か published 以外は 400 にする
  status?: PostStatus;

  // 画像のキー。API が発行した形（posts/ で始まる）のものだけを受け付ける
  @IsOptional()
  @IsString()
  @Matches(/^posts\//)
  imageKey?: string;
}
