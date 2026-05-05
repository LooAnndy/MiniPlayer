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

  // 创建 AVPlayer 实例并注册状态机回调（幂等，避免重复创建导致播放中断）
  async initPlayer() {
    if (this.avPlayer) return;
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

  // 设置播放源 URL（普通流：网易云/QQ，URL 自身含鉴权参数）
  async setUrl(url: string) {
    if (!this.avPlayer) return;
    try {
      this.avPlayer.url = url;
    } catch (err) {
      console.error('Failed to set url:', (err as BusinessError).message);
    }
  }

  /**
   * 设置带鉴权头的播放源（B站等需要 Referer 的 CDN）
   * 通过 createMediaSourceWithUrl 传递 HTTP 请求头，满足 CDN 鉴权
   */
  async setUrlWithHeaders(url: string, headers: Record<string, string>) {
    if (!this.avPlayer) return;
    try {
      const mediaSrc = media.createMediaSourceWithUrl(url, headers);
      this.avPlayer.setMediaSource(mediaSrc);
    } catch (err) {
      console.error('Failed to set url with headers:', (err as BusinessError).message);
    }
  }

  // 准备播放：由 initialized 状态触发
  async prepare() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.prepare();
      console.info('Succeeded in preparing');
    } catch (err) {
      console.error('Failed to prepare, error message is :' + (err as BusinessError).message);
      // 异常时重置播放器，以便重新设置资源
      this.avPlayer?.reset();
    }
  }

  // 开始播放：仅 prepared / paused / stopped / completed 状态有效
  async play() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.play();
      console.info('Succeeded in playing');
    } catch (err) {
      console.error('Failed to play, error message is :' + (err as BusinessError).message);
    }
  }

  // 暂停播放
  async pause() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.pause();
      console.info('Succeeded in pausing');
    } catch (err) {
      console.error('Failed to pause, error message is :' + (err as BusinessError).message);
    }
  }

  // 停止播放（回退到 prepared 状态，再次 play 从头开始）
  async stop() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.stop();
      console.info('Succeeded in stopping');
    } catch (err) {
      console.error('Failed to stop, error message is :' + (err as BusinessError).message);
    }
  }

  // 重置播放器（回到 idle 状态）
  async reset() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      console.info('Succeeded in resetting');
    } catch (err) {
      console.error('Failed to reset, error message is :' + (err as BusinessError).message);
    }
  }

  // 跳转到指定位置（毫秒）
  async seek(position: number) {
    if (!this.avPlayer) return;
    try {
      // seek 使用 callback 方式，不返回 Promise，但官方示例中同样需要异常处理
      this.avPlayer.seek(position);
      console.info('Succeeded in seeking');
    } catch (err) {
      console.error('Failed to seek, error message is :' + (err as BusinessError).message);
    }
  }

  // 释放播放器资源（退出页面时调用）
  async release() {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.release();
      console.info('Succeeded in releasing');
      this.avPlayer = null;
    } catch (err) {
      console.error('Failed to release, error message is :' + (err as BusinessError).message);
      this.avPlayer = null;
    }
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
}
