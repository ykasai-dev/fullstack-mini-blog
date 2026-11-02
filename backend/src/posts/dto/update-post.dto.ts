import { PartialType } from '@nestjs/mapped-types';
import { CreatePostDto } from './create-post.dto.js';

// 作成のときのルールを引き継ぎ、すべての項目を省略できるようにする
export class UpdatePostDto extends PartialType(CreatePostDto) {}
