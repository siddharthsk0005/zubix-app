import express from 'express';
import cors from 'cors';
import { corsOrigins } from './config/env';
import { authRouter } from './routes/auth';
import { adminAuthRouter } from './routes/admin-auth';
import { adminRouter } from './routes/admin';
import { brandsRouter } from './routes/brands';
import { categoriesRouter } from './routes/categories';
import { couponsRouter, sessionsRouter } from './routes/shopper';
import { errorHandler, notFound } from './middleware/errors';

export const app = express();

app.disable('x-powered-by');
app.use(
  cors({
    origin: (origin, callback) => {
      // Native mobile clients send no Origin header, so allow requests without one.
      if (!origin || corsOrigins.includes(origin)) {
        return callback(null, true);
      }
      return callback(null, false);
    },
  }),
);
app.use(express.json({ limit: '100kb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'zubix-api' });
});

app.use('/auth', authRouter);
app.use('/admin/auth', adminAuthRouter);
app.use('/admin', adminRouter);
app.use('/brands', brandsRouter);
app.use('/categories', categoriesRouter);
app.use('/sessions', sessionsRouter);
app.use('/coupons', couponsRouter);

app.use(notFound);
app.use(errorHandler);
