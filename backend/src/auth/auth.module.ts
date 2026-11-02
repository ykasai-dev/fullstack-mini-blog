import { Module } from '@nestjs/common';
import { AuthGuard } from './auth.guard.js';
import { AuthService } from './auth.service.js';

@Module({
  providers: [AuthService, AuthGuard],
  // ほかの Module（PostsModule・StorageModule）で AuthGuard を使えるようにする
  exports: [AuthService, AuthGuard],
})
export class AuthModule {}
