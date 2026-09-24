import { z } from 'zod';

/**
 * Kept deliberately close to lib/shared/validators.dart.
 *
 * The client validates first so the patient gets an instant answer; the server
 * validates because the client is not a security boundary. Where they differ,
 * the server is the authority — but they should not differ by accident.
 */
export const emailSchema = z
  .string()
  .trim()
  .toLowerCase()
  .min(3)
  .max(254)
  .regex(/^[^@\s]+@[^@\s.]+\.[^@\s]{2,}$/, 'That does not look like an email address.');

export const signUpSchema = z.object({
  name: z.string().trim().min(2, 'That name looks too short.').max(120),
  email: emailSchema,
  password: z
    .string()
    .min(8, 'Use at least 8 characters. Longer is safer than complicated.')
    .max(200),
});

export const signInSchema = z.object({
  email: emailSchema,
  // No length rule on sign-in: an existing password that predates a rule
  // change is still the patient's password, and refusing to send it locks them
  // out of their own account.
  password: z.string().min(1, 'Enter your password.'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export const resetRequestSchema = z.object({ email: emailSchema });

export const resetConfirmSchema = z.object({
  token: z.string().min(1),
  password: z.string().min(8).max(200),
});

export type SignUpInput = z.infer<typeof signUpSchema>;
export type SignInInput = z.infer<typeof signInSchema>;
