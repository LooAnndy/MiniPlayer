/**
 * 音频播放服务 —— 封装 @ohos.multimedia.media AVPlayer，管理播放状态机
 */
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';

export class AVPlayerService {
  private avPlayer: media.AVPlayer | null = null;

  // 回调接口：供 ViewModel 订阅播放器事件
  public onStateChanged?: (state: string) => void;
  public onError?: (error: BusinessError) => void;
  public onTimeUpdate?: (currentTime: number, duration: number) => void;
  public onDurationUpdate?: (duration: number) => void;
  public onSeekDone?: () => void;

  // 创建 AVPlayer 实例并注册状态机回调
  async initPlayer() {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback();
    } catch (error) {
      console.error('创建AVPlayer失败:', JSON.stringify(error));
    }
  }

  // 注册播放器事件监听：状态变化、错误、时长更新、时间更新、跳转完成
  private setAVPlayerCallback() {
    if (!this.avPlayer) return;

    // 播放器状态机变化（idle → initialized → prepared → playing → paused → completed）
    this.avPlayer.on('stateChange', (state: string) => {
      console.info(`AVPlayer state changed to: ${state}`);
      this.onStateChanged?.(state);
    });

    // 播放错误回调
    this.avPlayer.on('error', (error: BusinessError) => {
      console.error('AVPlayer error:', JSON.stringify(error));
      this.onError?.(error);
    });

    // 总时长更新（prepare 完成后触发）
    this.avPlayer.on('durationUpdate', (duration: number) => {
      console.info(`durationUpdate: ${duration}ms`);
      this.onDurationUpdate?.(duration);
    });

    // 播放进度更新（约每 300ms 触发一次）
    this.avPlayer.on('timeUpdate', (time: number) => {
      if (this.avPlayer) {
        const duration = this.avPlayer.duration;
        this.onTimeUpdate?.(time, duration);
      }
    });

    // seek 操作完成回调
    this.avPlayer.on('seekDone', () => {
      console.info('seekDone');
      this.onSeekDone?.();
    });
  }

  // 设置播放源 URL（支持 fd:// 本地文件和 https:// 网络流）
  async setUrl(url: string) {
    if (!this.avPlayer) return;
    this.avPlayer.url = url;
  }

  // 准备播放：由 initialized 状态触发
  async prepare() {
    if (!this.avPlayer) return;
    await this.avPlayer.prepare();
  }

  // 开始播放：仅 prepared / paused / stopped / completed 状态有效
  async play() {
    if (!this.avPlayer) return;
    await this.avPlayer.play();
  }

  // 暂停播放
  async pause() {
    if (!this.avPlayer) return;
    await this.avPlayer.pause();
  }

  // 停止播放（回退到 prepared 状态，再次 play 从头开始）
  async stop() {
    if (!this.avPlayer) return;
    await this.avPlayer.stop();
  }

  // 重置播放器（回到 idle 状态）
  async reset() {
    if (!this.avPlayer) return;
    await this.avPlayer.reset();
  }

  // 跳转到指定位置（毫秒）
  async seek(position: number) {
    if (!this.avPlayer) return;
    await this.avPlayer.seek(position);
  }

  // 获取当前播放器状态
  getState(): string {
    return this.avPlayer?.state || 'idle';
  }

  // 获取当前播放时间（毫秒）
  getCurrentTime(): number {
    return this.avPlayer?.currentTime || 0;
  }

  // 获取总时长（毫秒）
  getDuration(): number {
    return this.avPlayer?.duration || 0;
  }

  // 释放播放器资源（退出页面时调用）
  async release() {
    if (!this.avPlayer) return;
    await this.avPlayer.release();
    this.avPlayer = null;
  }
}
