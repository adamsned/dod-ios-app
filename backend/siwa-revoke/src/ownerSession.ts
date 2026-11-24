// Owner session helpers (DUT-861). Pure + stateless; index.ts wires them in.
export interface AppleJwk {
  kid: string
  kty: string
  n: string
  e: string
}

export const APPLE_ISSUER = "https://appleid.apple.com"

export function b64urlToBytes(s: string): Uint8Array {
  const pad = "=".repeat((4 - (s.length % 4)) % 4)
  const bin = atob(s.replace(/-/g, "+").replace(/_/g, "/") + pad)
  return Uint8Array.from(bin, (c) => c.charCodeAt(0))
}

// Returns the VERIFIED `sub`, or null for anything forged/expired/wrong-audience.
// Never trusts a client-asserted sub: the sub comes only from a signature-valid token.
export async function verifyAppleIdentityToken(
  token: string,
  jwks: AppleJwk[],
  audience: string,
  nowSeconds: number
): Promise<string | null> {
  const parts = token.split(".")
  if (parts.length !== 3) return null
  try {
    const dec = new TextDecoder()
    const header = JSON.parse(dec.decode(b64urlToBytes(parts[0])))
    if (header.alg !== "RS256") return null
    const jwk = jwks.find((k) => k.kid === header.kid)
    if (!jwk) return null
    const key = await crypto.subtle.importKey(
      "jwk",
      { kty: "RSA", n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    )
    const ok = await crypto.subtle.verify(
      "RSASSA-PKCS1-v1_5",
      key,
      b64urlToBytes(parts[2]),
      new TextEncoder().encode(`${parts[0]}.${parts[1]}`)
    )
    if (!ok) return null
    const payload = JSON.parse(dec.decode(b64urlToBytes(parts[1])))
    if (payload.iss !== APPLE_ISSUER) return null
    if (payload.aud !== audience) return null
    if (typeof payload.exp !== "number" || payload.exp <= nowSeconds) return null
    if (typeof payload.sub !== "string" || payload.sub.length === 0) return null
    return payload.sub
  } catch {
    return null
  }
}
