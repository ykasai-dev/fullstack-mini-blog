import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module.js';
import { StorageService } from './storage.service.js';
import { UploadsController } from './uploads.controller.js';

@Module({
  imports: [AuthModule], // UploadsController で AuthGuard を使う
  controllers: [UploadsController],
  providers: [StorageService],
  exports: [StorageService], // PostsModule で表示用の URL を作るのに使う（4-2-7）
})
export class StorageModule {}
