// service/AVPlayerService.ets
import media from '@ohos.multimedia.media';
import { BusinessError } from '@ohos.base';

export class AVPlayerService {
  private avPlayer: media.AVPlayer | null = null;

  // 状态变化回调
  public onStateChanged?: (state: string) => void;
  public onError?: (error: BusinessError) => void;
  // 进度更新回调
  public onTimeUpdate?: (currentTime: number, duration: number) => void;
  public onDurationUpdate?: (duration: number) => void;
  public onSeekDone?: () => void;

  // 初始化播放器
  async initPlayer() {
    try {
      this.avPlayer = await media.createAVPlayer();
      this.setAVPlayerCallback();
    } catch (error) {
      console.error('创建AVPlayer失败:', JSON.stringify(error));
    }
  }

  // 设置状态机回调
  private setAVPlayerCallback() {
    if (!this.avPlayer) return;

    // 监听状态机变化
    this.avPlayer.on('stateChange', (state: string) => {
      console.info(`AVPlayer state changed to: ${state}`);
      this.onStateChanged?.(state);
    });

    // 监听错误
    this.avPlayer.on('error', (error: BusinessError) => {
      console.error('AVPlayer error:', JSON.stringify(error));
      this.onError?.(error);
    });

    // 【新增】监听时长更新
    this.avPlayer.on('durationUpdate', (duration: number) => {
      console.info(`durationUpdate: ${duration}ms`);
      this.onDurationUpdate?.(duration);
    });

    // 【新增】监听时间更新（用于进度条）
    this.avPlayer.on('timeUpdate', (time: number) => {
      console.info(`timeUpdate: ${time}ms`);
      if (this.avPlayer) {
        const duration = this.avPlayer.duration;
        this.onTimeUpdate?.(time, duration);
      }
    });

    // 【新增】监听跳转完成
    this.avPlayer.on('seekDone', () => {
      console.info('seekDone');
      this.onSeekDone?.();
    });
  }

  // 设置播放源
  async setUrl(url: string) {
    if (!this.avPlayer) return;
    this.avPlayer.url = url;
  }

  // 准备播放 (由 initialized 状态触发)
  async prepare() {
    if (!this.avPlayer) return;
    await this.avPlayer.prepare();
  }

  // 开始播放
  async play() {
    if (!this.avPlayer) return;
    // 只有在 prepared, paused, stopped, completed 状态下才能调用 play
    await this.avPlayer.play();
  }

  // 暂停播放
  async pause() {
    if (!this.avPlayer) return;
    await this.avPlayer.pause();
  }

  // 停止播放，显示当前帧，再次播放时从头开始播放。
  async stop() {
    if (!this.avPlayer) return;
    await this.avPlayer.stop();
  }

  // 播放器回到idle状态
  async reset() {
    if (!this.avPlayer) return;
    await this.avPlayer.reset();
  }
  // 【新增】跳转到指定位置
  async seek(position: number) {
    if (!this.avPlayer) return;
    await this.avPlayer.seek(position);
  }

  // 获取当前播放器状态
  getState(): string {
    return this.avPlayer?.state || 'idle';
  }

  // 获取当前播放时间
  getCurrentTime(): number {
    return this.avPlayer?.currentTime || 0;
  }

  // 获取总时长
  getDuration(): number {
    return this.avPlayer?.duration || 0;
  }

  // 释放资源
  async release() {
    if (!this.avPlayer) return;
    await this.avPlayer.release();
    this.avPlayer = null;
  }
}
