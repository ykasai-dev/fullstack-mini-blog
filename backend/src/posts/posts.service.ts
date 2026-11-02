import { Injectable } from '@nestjs/common';
import type { Post, PostStatus } from '../generated/prisma/client.js';
import { PostsRepository } from './posts.repository.js';
import { StorageService } from '../storage/storage.service.js';

@Injectable()
export class PostsService {
  constructor(
    private readonly postsRepository: PostsRepository,
    private readonly storageService: StorageService,
  ) {}

  // 画像があれば、表示用の署名付き URL（imageUrl）を添える
  private async withImageUrl(post: Post) {
    return {
      ...post,
      imageUrl: post.imageKey
        ? await this.storageService.createDownloadUrl(post.imageKey)
        : null,
    };
  }

  async findAll() {
    const posts = await this.postsRepository.findAll();
    return Promise.all(posts.map((post) => this.withImageUrl(post)));
  }

  async findOne(id: number) {
    const post = await this.postsRepository.findById(id);
    return post ? this.withImageUrl(post) : null;
  }

  create(data: {
    title: string;
    body: string;
    status?: PostStatus;
    imageKey?: string;
  }): Promise<Post> {
    return this.postsRepository.create(data);
  }

  async update(
    id: number,
    data: {
      title?: string;
      body?: string;
      status?: PostStatus;
      imageKey?: string;
    },
  ): Promise<Post | null> {
    const post = await this.postsRepository.findById(id);
    if (!post) {
      return null;
    }
    return this.postsRepository.update(id, data);
  }
}
