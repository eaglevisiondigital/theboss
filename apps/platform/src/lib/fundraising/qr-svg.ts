import QRCode from "qrcode";
export function qrSvg(url: string) { return QRCode.toString(url, { type: "svg", errorCorrectionLevel: "M", margin: 4, width: 240 }); }
