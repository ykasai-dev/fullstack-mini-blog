import { IsIn } from 'class-validator';

export class CreateUploadDto {
  // 画像の形式だけを受け付ける
  @IsIn(['image/jpeg', 'image/png', 'image/gif', 'image/webp'])
  contentType: string;
}
