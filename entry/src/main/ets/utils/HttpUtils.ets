/**
 * HTTP 请求工具 —— 封装 @ohos.net.http（API 23）
 * 使用原生 Promise 接口发起 GET/POST 请求
 *
 * 参考文档: @ohos.net.http (数据请求)
 * - import { http } from '@kit.NetworkKit'
 * - header 支持 Record<string, string> 格式
 * - request() 返回 Promise<HttpResponse>
 */
import { http } from '@kit.NetworkKit';

export class HttpUtils {
  private httpClient: http.HttpRequest;

  constructor() {
    this.httpClient = http.createHttp();
  }

  /**
   * 发起 HTTP 请求（Promise 版本，API 23）
   * @param url 请求地址
   * @param options 请求配置
   */
  async request<T>(url: string, options?: http.HttpRequestOptions): Promise<T> {
    const response: http.HttpResponse = await this.httpClient.request(url, options);
    const code = typeof response.responseCode === 'number' ? response.responseCode : 0;
    console.info(`HTTP ${code}: ${url}`);

    // result 类型取决于 expectDataType 或服务端 Content-Type
    if (typeof response.result === 'string') {
      try {
        return JSON.parse(response.result) as T;
      } catch (e) {
        throw new Error(`JSON 解析失败: ${url}`);
      }
    }
    return response.result as T;
  }

  /**
   * POST form-urlencoded 请求（对应网易云搜索等常规 API）
   * extraData 按 key1=value1&key2=value2 编码为字符串
   */
  async postForm<T>(url: string, formData: Record<string, string>, headers?: Record<string, string>): Promise<T> {
    const body = Object.keys(formData)
      .map((key) => `${encodeURIComponent(key)}=${encodeURIComponent(formData[key])}`)
      .join('&');

    // 合并请求头（ArkTS 不支持对象展开，使用 Object.assign）
    const mergedHeaders: Record<string, string> = { 'Content-Type': 'application/x-www-form-urlencoded' };
    if (headers) {
      Object.keys(headers).forEach((key) => {
        mergedHeaders[key] = headers[key];
      });
    }

    return this.request<T>(url, {
      method: http.RequestMethod.POST,
      header: mergedHeaders,
      extraData: body,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 60000,
      readTimeout: 60000
    });
  }

  destroy(): void {
    this.httpClient.destroy();
  }
}
