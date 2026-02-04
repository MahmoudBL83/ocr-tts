import dotenv from 'dotenv';
// Load .env but don't override existing env vars (Vercel sets them)
dotenv.config({ override: false });

import express from 'express';
import cors from 'cors';
import helmet from 'helmet';

import healthRouter from './routes/health';
import requestsRouter from './routes/requests';
import { authenticate } from './middleware/auth';
import { ProcessingWorker } from './workers/processing.worker';

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use('/v1', healthRouter);
app.use('/v1', requestsRouter);

app.get('/v1/protected', authenticate, (req, res) => {
  res.json({ message: 'Authenticated access', uid: (req as any).uid });
});

const worker = new ProcessingWorker();
worker.start();

const port = process.env.PORT ? Number(process.env.PORT) : 3000;
app.listen(port, () => {
  console.log(`Server listening on http://localhost:${port}`);
});
