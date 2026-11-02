import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import type { Request } from 'express';
import { AuthService } from './auth.service.js';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(private readonly authService: AuthService) {}

  // true を返すとリクエストを通す。例外を投げると、その時点で 401 を返す
  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    // 「Authorization: Bearer （トークン）」の形のヘッダーから、トークンだけを取り出す
    const token = request.headers.authorization?.replace(/^Bearer /, '');
    if (!token) {
      throw new UnauthorizedException('Login required');
    }

    const payload = await this.authService.verifyAccessToken(token);
    if (!payload) {
      throw new UnauthorizedException('Invalid token');
    }
    return true;
  }
}
