import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module.js';
import { PostsRepository } from './posts.repository.js';
import { PostsService } from './posts.service.js';
import { PostsController } from './posts.controller.js';
import { AuthModule } from '../auth/auth.module.js';
import { StorageModule } from '../storage/storage.module.js';

@Module({
  imports: [DatabaseModule, AuthModule, StorageModule],
  controllers: [PostsController],
  providers: [PostsRepository, PostsService],
})
export class PostsModule {}
