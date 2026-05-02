/**
 * 文件服务 —— 封装系统文件选择器与沙箱文件读写
 * 使用 @ohos.file.picker 选择文件，@ohos.file.fs 打开为 fd:// 路径供 AVPlayer 播放
 */
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';

// 播放源数据结构：fdUrl 供 AVPlayer 设置，fd 用于后续关闭
export interface PlaySource {
  fdUrl: string;
  fd: number;
}

export class FileService {
  // 调起系统文件选择器，返回选中文件的 URI
  async selectLocalFile(): Promise<string | null> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      const documentPicker = new picker.DocumentViewPicker();
      const uris = await documentPicker.select(documentSelectOptions);

      if (uris && uris.length > 0) {
        return uris[0];
      }
      return null;
    } catch (error) {
      console.error('选择文件失败:', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 打开沙箱文件并生成 fd:// 协议路径
   * 参照 HarmonyOS 官方文档：使用 fs.open 获取文件描述符，拼接 fd:// 路径供 media.AVPlayer 使用
   */
  async openFileAsFdUrl(fileUri: string): Promise<PlaySource | null> {
    try {
      let fdPath = 'fd://';
      let file = await fs.open(fileUri, fs.OpenMode.READ_ONLY);
      fdPath = fdPath + '' + file.fd;

      console.info(`FileService: 成功打开文件，fdUrl = ${fdPath}`);
      return {
        fdUrl: fdPath,
        fd: file.fd
      };
    } catch (error) {
      console.error('打开文件失败:', JSON.stringify(error));
      return null;
    }
  }

  // 关闭文件描述符（播放结束时调用，防止内存泄漏）
  closeFileFd(fd: number) {
    try {
      fs.closeSync(fd);
      console.info(`FileService: 成功关闭 fd = ${fd}`);
    } catch (error) {
      console.error('关闭fd失败:', JSON.stringify(error));
    }
  }
}
