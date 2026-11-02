import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client.js';

@Injectable() // NestJS がインスタンスを作り、DI で渡せるクラスにする
export class PrismaService extends PrismaClient implements OnModuleDestroy {
  constructor() {
    // 接続先は環境変数から読む（手元の PC と AWS で、値だけを変える）
    super({
      adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
    });
  }

  // アプリの終了時に、データベースとの接続を閉じる
  async onModuleDestroy() {
    await this.$disconnect();
  }
}
