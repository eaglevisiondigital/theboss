function property(error: unknown, key: string): unknown {
 try { return error !== null && typeof error === "object" ? Reflect.get(error, key) : undefined; } catch { return undefined; }
}
// Only finite categories, numeric digests and explicitly allowlisted source frames.
export function finiteErrorDetails<T extends string>(error: unknown, files: readonly T[]) {
 const name = property(error,"name"), digest = property(error,"digest"), stack = property(error,"stack");
 const category = ["Error","TypeError","RangeError","ReferenceError","SyntaxError","AggregateError","URIError","EvalError"].includes(typeof name === "string" ? name : "") ? name as string : "UnknownError";
 let source: {file:T;line:number;column:number}|null = null;
 if(typeof stack === "string" && stack.length <= 32_000) {
  for(const frame of stack.split("\n").slice(1,21)) {
   if(!/^\s*at\s/.test(frame)) continue;
   for(const file of files) {
    const at=frame.indexOf(file+":");
    if(at<0 || (at>0 && !/[/(\\]/.test(frame[at-1]))) continue;
    const location=/^(\d{1,6}):(\d{1,6})(?:\)|\s|$)/.exec(frame.slice(at+file.length+1));
    if(location && Number(location[1])>0 && Number(location[2])>0) {source={file,line:Number(location[1]),column:Number(location[2])};break;}
   }
   if(source) break;
  }
 }
 return {exception_category:category,digest:typeof digest==="string" && /^[0-9]{1,20}$/.test(digest)?digest:null,source};
}
