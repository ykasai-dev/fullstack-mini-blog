import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';
import { PostsModule } from './posts/posts.module.js';
import { StorageModule } from './storage/storage.module.js';

@Module({
  imports: [PostsModule, StorageModule],
  controllers: [AppController], // GET /（Hello World）は残しておく
  providers: [AppService],
})
export class AppModule {}
