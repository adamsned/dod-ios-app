// Shared-secret gate. Compares SHA-256 digests so the comparison runs over
// fixed-length buffers with no early exit (same approach as siwa-revoke).
export async function isAuthorized(provided: string | null, secret: string): Promise<boolean> {
  if (!secret) return false // an unset secret must never authorize anything
  const [a, b] = await Promise.all([sha256(provided ?? ""), sha256(secret)])
  let diff = a.length ^ b.length
  for (let i = 0; i < a.length && i < b.length; i++) diff |= a[i] ^ b[i]
  return diff === 0
}

async function sha256(input: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input)))
}
