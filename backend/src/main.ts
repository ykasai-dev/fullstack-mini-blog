import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { ValidationPipe } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.enableCors({ origin: process.env.CORS_ORIGIN });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true }));

  // アクセスのログ：1つのリクエストを1行で出力する（例：GET /posts 200 12ms）
  app.use((req: Request, res: Response, next: NextFunction) => {
    const start = Date.now();
    // レスポンスを返し終わったときに出力する（ステータスコードがわかるため）
    res.on('finish', () => {
      // ALB のヘルスチェックは件数が多いので出力しない
      if (req.get('user-agent')?.startsWith('ELB-HealthChecker')) return;
      console.log(
        `${req.method} ${req.originalUrl} ${res.statusCode} ${Date.now() - start}ms`,
      );
    });
    next();
  });

  await app.listen(process.env.PORT ?? 3001);
}
await bootstrap();
