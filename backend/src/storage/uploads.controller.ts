import { Body, Controller, Post, UseGuards } from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard.js';
import { CreateUploadDto } from './dto/create-upload.dto.js';
import { StorageService } from './storage.service.js';

@Controller('uploads')
export class UploadsController {
  constructor(private readonly storageService: StorageService) {}

  // POST /uploads：アップロード用の署名付き URL を返す（ログインが必要）
  @Post()
  @UseGuards(AuthGuard)
  create(@Body() input: CreateUploadDto) {
    return this.storageService.createUploadUrl(input.contentType);
  }
}
