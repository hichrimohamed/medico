import mongoose from 'mongoose';
import { env } from '../config/env.js';

export async function connectDatabase(uri: string = env.MONGODB_URI) {
  mongoose.set('strictQuery', true);
  await mongoose.connect(uri);

  // Unique indexes are the booking correctness guarantee, and Mongoose builds
  // them in the background. Waiting here means the first request cannot race
  // an index that does not exist yet.
  await Promise.all(mongoose.modelNames().map((name) => mongoose.model(name).init()));

  return mongoose.connection;
}

export async function disconnectDatabase() {
  await mongoose.disconnect();
}
