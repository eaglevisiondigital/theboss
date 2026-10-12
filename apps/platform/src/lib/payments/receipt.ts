import { bucksMoney } from "../boss-bucks/money";
import { paymentRecord } from "./input";
/** Canonical receipt content is independent of delivery-provider availability. */
export function paymentReceiptContent(receipt:unknown):{subject:string;text:string}|null {
 if(!paymentRecord(receipt)||typeof receipt.payment_id!=="string"||!/^[a-f0-9-]{36}$/i.test(receipt.payment_id)||typeof receipt.organization!=="string"||receipt.organization.length>200||!['card','ach'].includes(String(receipt.method))||typeof receipt.currency!=="string"||!/^[A-Z]{3}$/.test(receipt.currency))return null;
 const amount=String(receipt.amount_minor),principal=String(receipt.principal_minor),refund=String(receipt.refunded_minor);
 if(![amount,principal,refund].every(x=>/^(0|[1-9][0-9]{0,9})$/.test(x)&&BigInt(x)<=1000000000n))return null;
 return {subject:"Boss payment receipt",text:`${receipt.organization}\nReceipt ${receipt.payment_id}\n${String(receipt.method).toUpperCase()} payment ${bucksMoney(amount,receipt.currency)}\nPrincipal ${bucksMoney(principal,receipt.currency)}\nRefunded ${bucksMoney(refund,receipt.currency)}\nPayment success and organization settlement are separate.`};
}
