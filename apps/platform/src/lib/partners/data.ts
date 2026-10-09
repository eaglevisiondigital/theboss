import "server-only";
import { createClient } from "../supabase/server";
import { validAdminData,type PartnerAdminData } from "./contracts";
export async function loadPartners(providerId?:string):Promise<PartnerAdminData> {
 try {const client=await createClient(),{data,error}=await client.rpc("boss_partners_read",{query:{mode:"admin",...(providerId?{provider_id:providerId}:{})}});
 if(error)return {unavailable:true,restricted:error.code==="PT403"};return validAdminData(data)?data:{unavailable:true};
 }catch{return {unavailable:true};}
}
