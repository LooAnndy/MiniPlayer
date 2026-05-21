/**
 * 音频播放服务 —— 封装 @ohos.multimedia.media AVPlayer，管理播放状态机
 *
 * 缓冲优化（参照华为官方流媒体播放开发指导）：
 *   - PlaybackStrategy.preferredBufferDuration = 20s（点播提前缓存，减少卡顿）
 *   - 监听 bufferingUpdate 事件，传递缓冲状态到上层
 *   - timeUpdate 节流至 250ms，减少 UI 线程压力
 *   - error 事件自动 reset() 恢复播放器
 */
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';

// timeUpdate 节流间隔（ms）
const TIME_UPDATE_THROTTLE_MS: number = 250;

export class AVPlayerService {
  private avPlayer: media.AVPlayer | null = null;
  private lastTimeUpdateTs: number = 0;

  // 回调接口：供 ViewModel 订阅播放器事件
  public onStateChanged?: (state: string) => void;
  public onError?: (error: BusinessError) => void;
  public onTimeUpdate?: (currentTime: number, duration: number) => void;
  public onDurationUpdate?: (duration: number) => void;
  public onSeekDone?: () => void;
  public onBufferingStart?: () => void;
  public onBufferingEnd?: () => void;

  // 创建 AVPlayer 实例并注册全部事件回调
  async initPlayer(): Promise<void> {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback();
    } catch (error) {
      console.error('创建AVPlayer失败:', JSON.stringify(error));
    }
  }

  private setAVPlayerCallback(): void {
    if (!this.avPlayer) return;

    this.avPlayer.on('stateChange', (state: string) => {
      console.info(`AVPlayer state changed to: ${state}`);
      this.onStateChanged?.(state);
    });

    // 错误回调：自动 reset 以便恢复播放器，同时通知上层
    this.avPlayer.on('error', (error: BusinessError) => {
      console.error('AVPlayer error:', JSON.stringify(error));
      this.avPlayer?.reset();
      this.onError?.(error);
    });

    this.avPlayer.on('durationUpdate', (duration: number) => {
      console.info(`durationUpdate: ${duration}ms`);
      this.onDurationUpdate?.(duration);
    });

    // 播放进度更新：节流至 250ms，降低 UI 刷新频率
    this.avPlayer.on('timeUpdate', (time: number) => {
      const now: number = Date.now();
      if (now - this.lastTimeUpdateTs < TIME_UPDATE_THROTTLE_MS) {
        return;
      }
      this.lastTimeUpdateTs = now;
      if (this.avPlayer) {
        const duration: number = this.avPlayer.duration;
        this.onTimeUpdate?.(time, duration);
      }
    });

    // 缓冲状态更新：BUFFERING_START / BUFFERING_PERCENT / BUFFERING_END / CACHED_DURATION
    this.avPlayer.on('bufferingUpdate', (infoType: media.BufferingInfoType) => {
      if (infoType === media.BufferingInfoType.BUFFERING_START) {
        console.info('AVPlayer buffering start');
        this.onBufferingStart?.();
      } else if (infoType === media.BufferingInfoType.BUFFERING_END) {
        console.info('AVPlayer buffering end');
        this.onBufferingEnd?.();
      }
    });

    this.avPlayer.on('seekDone', () => {
      console.info('seekDone');
      this.onSeekDone?.();
    });
  }

  /**
   * 设置普通流播放源（网易云/QQ，URL 自身含鉴权参数）
   * 使用 PlaybackStrategy 预缓冲 20 秒，减少卡顿
   */
  async setUrl(url: string): Promise<void> {
    if (!this.avPlayer) return;
    try {
      const mediaSrc: media.MediaSource = media.createMediaSourceWithUrl(url);
      const strategy: media.PlaybackStrategy = { preferredBufferDuration: 20 };
      this.avPlayer.setMediaSource(mediaSrc, strategy);
    } catch (err) {
      console.error('Failed to set url:', (err as BusinessError).message);
    }
  }

  /**
   * 设置带鉴权头的播放源（B站等需要 Referer 的 CDN）
   * 同时应用 PlaybackStrategy 预缓冲策略
   */
  async setUrlWithHeaders(url: string, headers: Record<string, string>): Promise<void> {
    if (!this.avPlayer) return;
    try {
      const mediaSrc: media.MediaSource = media.createMediaSourceWithUrl(url, headers);
      const strategy: media.PlaybackStrategy = { preferredBufferDuration: 20 };
      this.avPlayer.setMediaSource(mediaSrc, strategy);
    } catch (err) {
      console.error('Failed to set url with headers:', (err as BusinessError).message);
    }
  }

  async prepare(): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.prepare();
      console.info('Succeeded in preparing');
    } catch (err) {
      console.error('Failed to prepare, error message is :' + (err as BusinessError).message);
      this.avPlayer?.reset();
    }
  }

  async play(): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.play();
      console.info('Succeeded in playing');
    } catch (err) {
      console.error('Failed to play, error message is :' + (err as BusinessError).message);
    }
  }

  async pause(): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.pause();
      console.info('Succeeded in pausing');
    } catch (err) {
      console.error('Failed to pause, error message is :' + (err as BusinessError).message);
    }
  }

  async stop(): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.stop();
      console.info('Succeeded in stopping');
    } catch (err) {
      console.error('Failed to stop, error message is :' + (err as BusinessError).message);
    }
  }

  async reset(): Promise<void> {
    if (!this.avPlayer) return;
    try {
      await this.avPlayer.reset();
      console.info('Succeeded in resetting');
    } catch (err) {
      console.error('Failed to reset, error message is :' + (err as BusinessError).message);
    }
  }

  async seek(position: number): Promise<void> {
    if (!this.avPlayer) return;
    try {
      this.avPlayer.seek(position);
      console.info('Succeeded in seeking');
    } catch (err) {
      console.error('Failed to seek, error message is :' + (err as BusinessError).message);
    }
  }

  async release(): Promise<void> {
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

  getState(): string {
    return this.avPlayer?.state || 'idle';
  }

  getCurrentTime(): number {
    return this.avPlayer?.currentTime || 0;
  }

  getDuration(): number {
    return this.avPlayer?.duration || 0;
  }
}
