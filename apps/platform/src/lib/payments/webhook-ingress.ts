import { executePaymentOperation } from "./execution";
import { providerContextValid } from "./providers/contracts";
import type { PrivatePaymentRuntime } from "./runtime";
/** Signed webhook is a polling hint. Never trust its payment amount/status. */
export async function acceptPaymentWebhook(request: Request, accountId: string, runtime: PrivatePaymentRuntime | null): Promise<number> {
 if (!runtime) return 503;
 if (request.method !== "POST" || !/^[0-9a-f-]{36}$/i.test(accountId) || Number(request.headers.get("content-length") ?? 0) > 65536 || !request.body) return 400;
 try {
  const account = await runtime.account(accountId), credentials = account ? await runtime.resolveCredentials(account) : null;
  if (!account || !credentials || account.provider !== runtime.adapter.provider || !providerContextValid(account,credentials)) return 503;
  const reader=request.body.getReader(),chunks:Uint8Array[]=[];let size=0;
  for (;;) { const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>65536){await reader.cancel();return 413;}chunks.push(value); }
  const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
  const hint=runtime.adapter.verifyWebhook(bytes,request.headers,credentials);if(!hint)return 401;
  const checkout=await runtime.dispatchedCheckout(account.id,hint.transactionReference);if(!checkout)return 202;
  // Persist normalized authoritative retrieval only; raw body/headers are dropped.
  await executePaymentOperation(checkout,runtime.repository,runtime.adapter,runtime.resolveCredentials);return 202;
 } catch { return 503; }
}
