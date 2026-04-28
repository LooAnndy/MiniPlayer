import { AVPlayerService } from '../service/AVPlayerService';
import { FileService, PlaySource } from '../utils/FileUtils';
import { BusinessError } from '@ohos.base';

@ObservedV2
export default class PlayerViewModel {
  // UI状态变量
  @Trace message: string = '点击下方按钮选择音乐文件';
  @Trace isPlaying: boolean = false;
  @Trace currentFileName: string = '';
  @Trace playerState: string = 'idle';
  @Trace currentTime: number = 0;
  @Trace duration: number = 0;
  @Trace progressValue: number = 0;
  @Trace isDragging: boolean = false;

  // 服务实例
  private playerService: AVPlayerService = new AVPlayerService();
  private fileService: FileService = new FileService();
  private currentPlaySource: PlaySource | null = null;

  // 初始化播放器
  async initPlayer(): Promise<void> {
    await this.playerService.initPlayer();

    this.playerService.onStateChanged = (state: string) => {
      this.playerState = state;

      switch (state) {
        case 'initialized':
          this.playerService.prepare();
          break;
        case 'prepared':
          this.playerService.play();
          break;
        case 'playing':
          this.isPlaying = true;
          this.message = '正在播放...';
          break;
        case 'paused':
          this.isPlaying = false;
          this.message = '已暂停';
          break;
        case 'completed':
          this.isPlaying = false;
          this.message = '播放完成，已重置';
          this.playerService.reset();
          break;
        case 'idle':
          console.info('播放器已回到 idle 状态');
          break;
        case 'released':
          if (this.currentPlaySource) {
            this.fileService.closeFileFd(this.currentPlaySource.fd);
            this.currentPlaySource = null;
          }
          break;
      }
    };

    this.playerService.onError = (error: BusinessError) => {
      this.isPlaying = false;
      this.message = '播放出错: ' + error.message;
      if (this.currentPlaySource) {
        this.fileService.closeFileFd(this.currentPlaySource.fd);
        this.currentPlaySource = null;
      }
    };

    this.playerService.onDurationUpdate = (duration: number) => {
      this.duration = duration;
      console.info(`总时长: ${duration}ms`);
    };

    this.playerService.onTimeUpdate = (time: number, duration: number) => {
      if (!this.isDragging) {
        this.currentTime = time;
        this.duration = duration;
        if (duration > 0) {
          this.progressValue = Math.min(100, Math.max(0, (time / duration) * 100));
        }
      }
    };

    this.playerService.onSeekDone = () => {
      console.info('跳转完成');
      this.isDragging = false;
    };
  }

  // 选择并播放文件
  async selectAndPlay(): Promise<void> {
    const uri = await this.fileService.selectLocalFile();
    if (!uri) {
      this.message = '未选择文件';
      return;
    }

    this.currentFileName = uri.split('/').pop() || '未知文件';
    this.message = `正在加载: ${this.currentFileName}`;

    if (this.currentPlaySource) {
      this.fileService.closeFileFd(this.currentPlaySource.fd);
    }

    const source = await this.fileService.openFileAsFdUrl(uri);
    if (!source) {
      this.message = '文件打开失败';
      return;
    }
    this.currentPlaySource = source;

    this.playerService.setUrl(source.fdUrl);
  }

  // 播放/暂停切换
  async togglePlayPause(): Promise<void> {
    if (this.isPlaying) {
      await this.playerService.pause();
    } else {
      if (this.playerState === 'paused') {
        await this.playerService.play();
      } else if ((this.playerState === 'completed' || this.playerState === 'stopped' || this.playerState === 'idle') && this.currentPlaySource) {
        this.playerService.setUrl(this.currentPlaySource.fdUrl);
      }
    }
  }

  // 格式化时间
  formatTime(milliseconds: number): string {
    if (milliseconds <= 0) return '00:00';
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // 进度条拖拽开始
  onDragStart(): void {
    this.isDragging = true;
    console.info('开始拖拽进度条');
  }

  // 进度条拖拽中
  onDragMove(value: number): void {
    if (!this.isDragging) return;
    this.progressValue = value;
    const targetTime = (value / 100) * this.duration;
    this.currentTime = targetTime;
  }

  // 进度条拖拽结束
  async onDragEnd(value: number): Promise<void> {
    // 【关键修复】如果拖拽到了末尾（超过98%），自动触发完成状态
    if (value >= 98 && this.duration > 0) {
      console.info('拖拽到视频末尾，触发完成状态');
      this.isDragging = false;

      // 模拟播放完成
      this.playerState = 'completed';
      this.isPlaying = false;
      this.message = '播放完成，已重置';

      // 自动重置播放器
      await this.playerService.reset();

      // 更新进度到末尾
      this.currentTime = this.duration;
      this.progressValue = 100;
      return;
    }
    // 检查播放器是否处于可跳转的状态
    const validSeekStates = ['playing', 'paused', 'prepared', 'idle'];
    if (!validSeekStates.includes(this.playerState)) {
      console.warn(`当前状态 ${this.playerState} 不支持跳转`);
      this.isDragging = false;

      // 如果是完成状态，允许重新开始
      if (this.playerState === 'completed' && this.currentPlaySource) {
        console.info('从完成状态重新开始播放');
        this.playerService.setUrl(this.currentPlaySource.fdUrl);
        // 稍等片刻让播放器准备好
        setTimeout(async () => {
          await this.playerService.seek(Math.floor((value / 100) * this.duration));
        }, 100);
      }
      return;
    }

    if (!this.playerService || this.duration <= 0) return;
    const targetTime = Math.floor((value / 100) * this.duration);
    console.info(`跳转到: ${targetTime}ms (${this.formatTime(targetTime)})`);
    await this.playerService.seek(targetTime);
  }

  // 清理资源
  release(): void {
    this.playerService.release();
  }

  // 获取是否有当前播放源
  hasCurrentPlaySource(): boolean {
    return !!this.currentPlaySource;
  }
}
