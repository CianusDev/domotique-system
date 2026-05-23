import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import cookieParser from 'cookie-parser';
// import { doubleCsrf } from 'csrf-csrf';
import helmet from 'helmet';
import { NestExpressApplication } from '@nestjs/platform-express';
async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  app.use(cookieParser());
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  app.setGlobalPrefix('api');

  app.enableCors({
    origin: process.env.CORS_ORIGIN?.split(',') || ['http://localhost:3000'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: true,
  });
  //const { doubleCsrfProtection } = doubleCsrf({
  //   getSecret: () => {
  //     return process.env.CSRF_SECRET!;
  //   },
  //   getSessionIdentifier: (req) => {
  //     return req.ip || '';
  //   },
  //   cookieOptions: {
  //     httpOnly: true,
  //     sameSite: 'lax',
  //     secure: process.env.NODE_ENV === 'production',
  //   },
  // });
  // app.use(doubleCsrfProtection);
  app.set('trust proxy', 'loopback');
  app.use(
    helmet({
      contentSecurityPolicy: process.env.NODE_ENV === 'production',
      xContentTypeOptions: process.env.NODE_ENV === 'production',
      xFrameOptions: process.env.NODE_ENV === 'production',
    }),
  );

  await app.listen(process.env.PORT ?? 5000);
}
bootstrap();
