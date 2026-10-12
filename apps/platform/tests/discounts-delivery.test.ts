import { test } from "node:test";
import assert from "node:assert/strict";
import { performDiscountDeliveryRead, type DeliveryClient } from "../src/lib/discounts/delivery";
const id = "70000000-0000-4000-8000-000000000001", origin = "https://platform.boss.invalid";
function request(input: unknown,from = origin) { return new Request(`${origin}/app/boss-bucks/discounts/delivery`,{ method: "POST", headers: { origin: from,host: "platform.boss.invalid","content-type":"application/json" },body: JSON.stringify(input) }); }
const input = { organization_id:id,order_id:id };
test("delivery requires same origin before any private read", async () => {
 const client = { rpc: () => { throw new Error("Must not read"); } } as unknown as DeliveryClient;
 assert.equal((await performDiscountDeliveryRead(request(input,"https://evil.invalid"),client,origin)).status,403);
});
test("delivery does not let a caller supply private person, household, role or proof context", async () => {
 const client = { rpc: () => { throw new Error("Must not read"); } } as unknown as DeliveryClient;
 for (const field of ["person_id","household_id","role","capability","delivery","address"]) assert.equal((await performDiscountDeliveryRead(request({ ...input,[field]:id }),client,origin)).status,422);
});
test("delivery requires a verified current signed user", async () => {
 const client = { auth: { getUser: async () => ({ data:{ user:null },error:null }) },rpc: () => { throw new Error("Must not read"); } } as unknown as DeliveryClient;
 assert.equal((await performDiscountDeliveryRead(request(input),client,origin)).status,401);
});
