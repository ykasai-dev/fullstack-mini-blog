import {
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import type { Post as PostModel } from '../generated/prisma/client.js';
import { CreatePostDto } from './dto/create-post.dto.js';
import { PostsService } from './posts.service.js';
import { UpdatePostDto } from './dto/update-post.dto.js';
import { AuthGuard } from '../auth/auth.guard.js';

@Controller('posts') // /posts で始まる URL を担当する
export class PostsController {
  constructor(private readonly postsService: PostsService) {}

  @Get() // GET /posts
  findAll(): Promise<PostModel[]> {
    return this.postsService.findAll();
  }

  @Get(':id') // GET /posts/:id
  // ParseIntPipe：URL の :id を数値に変換する（数値でなければ 400 を返す）
  async findOne(@Param('id', ParseIntPipe) id: number): Promise<PostModel> {
    const post = await this.postsService.findOne(id);
    if (!post) {
      // HTTP のステータスコード（404）に変換するのは Controller の役割
      throw new NotFoundException(`Post ${id} not found`);
    }
    return post;
  }

  @Post() // POST /posts
  @UseGuards(AuthGuard) // ログインしていないと 401
  // @Body()：リクエストの本文（JSON）を、DTO のルールでチェックしてから受け取る
  create(@Body() input: CreatePostDto): Promise<PostModel> {
    return this.postsService.create(input);
  }

  @Patch(':id') // PATCH /posts/:id
  @UseGuards(AuthGuard)
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body() input: UpdatePostDto,
  ): Promise<PostModel> {
    const post = await this.postsService.update(id, input);
    if (!post) {
      throw new NotFoundException(`Post ${id} not found`);
    }
    return post;
  }
}
