/**
 * EAPI 加密工具 —— 实现网易云音乐 eapi 接口的 AES-128-ECB 加密
 * 基于 api-analysis/NetEase/API_ANALYSIS.md §3 核心加密协议
 *
 * 使用 @ohos.security.cryptoFramework (API 23):
 *   - createMd('MD5') 计算消息摘要
 *   - createSymKeyGenerator('AES128') 生成对称密钥
 *   - createCipher('AES128|ECB|PKCS7') AES-ECB 加密
 */
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { url } from '@kit.ArkTS';

const AES_KEY_BYTES: Uint8Array = new Uint8Array([
  0x65, 0x38, 0x32, 0x63, 0x6b, 0x65, 0x6e, 0x68, // "e82ckenh"
  0x38, 0x64, 0x69, 0x63, 0x68, 0x65, 0x6e, 0x38  // "8dichen8"
]);

const EAPI_DELIMITER = '-36cd479b6b5-';

/**
 * 将 Uint8Array 转换为十六进制小写字符串
 */
export function bytesToHex(bytes: Uint8Array): string {
  const hexChars: string = '0123456789abcdef';
  let result = '';
  for (let i = 0; i < bytes.length; i++) {
    result += hexChars[(bytes[i] >>> 4) & 0x0f];
    result += hexChars[bytes[i] & 0x0f];
  }
  return result;
}

/**
 * 将十六进制字符串转换为 Uint8Array
 */
function hexToBytes(hex: string): Uint8Array {
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < hex.length; i += 2) {
    bytes[i / 2] = parseInt(hex.substring(i, i + 2), 16);
  }
  return bytes;
}

/**
 * 计算 MD5 哈希，返回十六进制字符串
 */
async function md5Hex(input: string): Promise<string> {
  const md = cryptoFramework.createMd('MD5');
  const inputData: cryptoFramework.DataBlob = { data: new Uint8Array(bufferFrom(input, 'utf-8')) };

  await new Promise<void>((resolve, reject) => {
    md.update(inputData, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });

  const digestResult = await new Promise<cryptoFramework.DataBlob>((resolve, reject) => {
    md.digest((err, output) => {
      if (err) {
        reject(err);
      } else {
        resolve(output);
      }
    });
  });

  return bytesToHex(digestResult.data);
}

/**
 * AES-128-ECB-PKCS7 加密，返回十六进制字符串
 */
async function aesEcbEncrypt(plaintext: string): Promise<string> {
  // 生成 AES128 密钥
  const symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128');
  const keyData: cryptoFramework.DataBlob = { data: AES_KEY_BYTES };
  const symKey = await symKeyGenerator.convertKey(keyData);

  // 创建 AES-ECB 加密器
  const cipher = cryptoFramework.createCipher('AES128|ECB|PKCS7');

  // init
  await new Promise<void>((resolve, reject) => {
    cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, symKey, null, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });

  // doFinal
  const plainData: cryptoFramework.DataBlob = { data: new Uint8Array(bufferFrom(plaintext, 'utf-8')) };
  const encrypted = await new Promise<cryptoFramework.DataBlob>((resolve, reject) => {
    cipher.doFinal(plainData, (err, output) => {
      if (err) {
        reject(err);
      } else {
        resolve(output);
      }
    });
  });

  return bytesToHex(encrypted.data);
}

// 将字符串转为 Uint8Array 的辅助函数
function bufferFrom(str: string, _encoding: string): ArrayBuffer {
  const buf = new ArrayBuffer(str.length);
  const view = new Uint8Array(buf);
  for (let i = 0; i < str.length; i++) {
    view[i] = str.charCodeAt(i) & 0xff;
  }
  return buf;
}

/**
 * EAPI 参数加密
 * @param fullUrl 完整 URL（如 https://interface3.music.163.com/eapi/song/enhance/player/url/v1）
 * @param payload 请求参数的 JSON 对象
 * @returns hex 编码的加密字符串，作为 POST body 的 params 字段
 */
export async function eapiEncrypt(fullUrl: string, payload: object): Promise<string> {
  // 1. 提取路径，将 /eapi/ 替换为 /api/
  const urlObj = url.URL.parseURL(fullUrl);
  const urlPath = urlObj.pathname.replace('/eapi/', '/api/');

  // 2. 序列化 payload
  const payloadJson = JSON.stringify(payload);

  // 3. 计算 MD5 摘要
  const digestText = `nobody${urlPath}use${payloadJson}md5forencrypt`;
  const digest = await md5Hex(digestText);

  // 4. 构造明文
  const plaintext = `${urlPath}${EAPI_DELIMITER}${payloadJson}${EAPI_DELIMITER}${digest}`;

  // 5. AES-128-ECB 加密
  const encryptedHex = await aesEcbEncrypt(plaintext);

  return encryptedHex;
}
