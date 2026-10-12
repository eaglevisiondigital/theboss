/** Retain request identities only while a file upload outcome is uncertain. */
export class CommunicationUploadRetry {
  private current: { signature: string; request: string; completion: string } | null = null;
  request(signature: string, createId: () => string = () => crypto.randomUUID()) {
    if (this.current?.signature !== signature) this.current = { signature, request: createId(), completion: createId() };
    return this.current;
  }
  confirmed() { this.current = null; }
}
