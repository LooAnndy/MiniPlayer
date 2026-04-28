import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';

// 定义播放源数据结构
export interface PlaySource {
  fdUrl: string;   // 拼接好的 fd:// 路径
  fd: number;      // 打开的文件描述符，用于后续关闭
}

export class FileService {
  // 选择本地文件
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

  // 参照知识库文档：使用fs文件系统打开沙箱地址获取媒体文件地址并通过url属性进行播放
  async openFileAsFdUrl(fileUri: string): Promise<PlaySource | null> {
    try {
      let fdPath = 'fd://';
      // 打开相应的资源文件地址获取fd
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

  // 关闭文件描述符，防止内存泄漏
  closeFileFd(fd: number) {
    try {
      fs.closeSync(fd);
      console.info(`FileService: 成功关闭 fd = ${fd}`);
    } catch (error) {
      console.error('关闭fd失败:', JSON.stringify(error));
    }
  }
}
