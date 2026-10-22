export class WooError extends Error { constructor(public status: number, message: string) { super(message); } }
type Query = Record<string, string | number | boolean | undefined>;
export class WooClient {
  constructor(private baseUrl: string, private token: string, private timeoutMs: number) {}
  async request<T>(method: 'GET'|'POST'|'PUT', path: string, opts: {query?: Query; body?: unknown} = {}): Promise<T> {
    const url = new URL(`${this.baseUrl}/wp-json/wc/v3${path}`);
    for (const [key, value] of Object.entries(opts.query ?? {})) if (value !== undefined) url.searchParams.set(key, String(value));
    let response: Response;
    try { response = await fetch(url, { method, headers: {'X-Urumi-Store-Token': this.token, 'Content-Type':'application/json', Accept:'application/json'}, body: opts.body === undefined ? undefined : JSON.stringify(opts.body), signal: AbortSignal.timeout(this.timeoutMs), redirect:'error' }); }
    catch (error) { throw new WooError(503, `Store unreachable: ${(error as Error).message}`); }
    const raw = await response.text(); let data: unknown = raw; try { data = JSON.parse(raw); } catch { /* non JSON */ }
    if (!response.ok) throw new WooError(response.status, `WooCommerce ${response.status}: ${(data as {message?:string}).message ?? raw.slice(0, 200)}`);
    return data as T;
  }
  get<T>(path: string, query?: Query) { return this.request<T>('GET', path, {query}); }
  post<T>(path: string, body: unknown) { return this.request<T>('POST', path, {body}); }
  put<T>(path: string, body: unknown) { return this.request<T>('PUT', path, {body}); }
  async ping() { try { return (await fetch(`${this.baseUrl}/wp-json/`, {signal: AbortSignal.timeout(2000)})).ok; } catch { return false; } }
}
