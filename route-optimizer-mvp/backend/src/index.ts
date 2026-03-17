import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import locationsRouter from './routes/locations';
import scenariosRouter from './routes/scenarios';
import optimizeRouteRouter from './routes/optimizeRoute';
import computeEffectiveMoveRouter from './routes/computeEffectiveMove';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/locations', locationsRouter);
app.use('/api/scenarios', scenariosRouter);
app.use('/api/optimize-route', optimizeRouteRouter);
app.use('/api/compute-effective-move', computeEffectiveMoveRouter);

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => console.log(`Backend running on http://localhost:${PORT}`));
