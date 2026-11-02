import { Module } from '@nestjs/common';
import { PrismaService } from './prisma.service.js';

@Module({
  providers: [PrismaService], // この Module で作るクラス
  exports: [PrismaService], // imports したほかの Module でも使えるようにする
})
export class DatabaseModule {}
