import { SignJWT, importPKCS8, type CryptoKey } from "jose";

let cachedKey: CryptoKey | null = null;

async function getPrivateKey(): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const pem = process.env.LICENSE_PRIVATE_KEY_PEM;
  if (!pem) {
    throw new Error("LICENSE_PRIVATE_KEY_PEM env var is not set");
  }
  cachedKey = await importPKCS8(pem, "EdDSA");
  return cachedKey;
}

export async function signLicense(params: {
  customerId: string;
  sessionId: string;
  entitlements: string[];
}): Promise<string> {
  const key = await getPrivateKey();
  return await new SignJWT({ entitlements: params.entitlements })
    .setProtectedHeader({ alg: "EdDSA" })
    .setIssuer("d4mac.app")
    .setAudience("d4mac-client")
    .setSubject(params.customerId)
    .setJti(params.sessionId)
    .setIssuedAt()
    .sign(key);
}
