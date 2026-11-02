import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma.service.js';
import type { Post, PostStatus } from '../generated/prisma/client.js';

@Injectable()
export class PostsRepository {
  constructor(private readonly prisma: PrismaService) {} // DI で受け取る

  // Prisma の操作は、Repository の中だけに書く
  findAll(): Promise<Post[]> {
    return this.prisma.post.findMany({
      // 新しい順。作成の時刻が同じ記事は id の大きい順にする（順番が必ず決まるように）
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    });
  }

  findById(id: number): Promise<Post | null> {
    return this.prisma.post.findUnique({ where: { id } });
  }

  create(data: {
    title: string;
    body: string;
    status?: PostStatus;
    imageKey?: string;

  }): Promise<Post> {
    return this.prisma.post.create({ data });
  }

  update(
    id: number,
    data: { 
      title?: string;
      body?: string; 
      status?: PostStatus,
      imageKey?: string,
    },
  ): Promise<Post> {
    return this.prisma.post.update({ where: { id }, data });
  }
}
