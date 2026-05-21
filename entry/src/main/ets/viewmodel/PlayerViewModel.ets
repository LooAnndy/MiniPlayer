/**
 * 播放器 ViewModel —— 管理播放状态、进度、拖拽交互，桥接 UI 与 AVPlayerService
 */
import { AVPlayerService } from '../service/AVPlayerService';
import { FileService, PlaySource } from '../utils/FileUtils';
import { BusinessError } from '@ohos.base';

@ObservedV2
export default class PlayerViewModel {
  // @Trace 修饰的属性变化时自动通知 @ComponentV2 刷新 UI
  @Trace message: string = '点击下方按钮选择音乐文件';
  @Trace isPlaying: boolean = false;
  @Trace isPlayed: boolean = false;  // 是否有过播放历史（控制 PlayerBar 显示）
  @Trace isBuffering: boolean = false;  // 是否正在缓冲（控制 loading 动画）
  @Trace currentFileName: string = '';
  @Trace playerState: string = 'idle';
  @Trace currentTime: number = 0;
  @Trace duration: number = 0;
  @Trace progressValue: number = 0;
  @Trace isDragging: boolean = false;

  // 底层服务实例（非 UI 状态，不需要 @Trace）
  private playerService: AVPlayerService = new AVPlayerService();
  private fileService: FileService = new FileService();
  private currentPlaySource: PlaySource | null = null;
  private lastStreamUrl: string = '';

  /**
   * 初始化播放器：创建 AVPlayer 实例并绑定状态回调
   * 状态机流转：initialized → prepared → playing ↔ paused → completed → idle
   */
  async initPlayer(): Promise<void> {
    await this.playerService.initPlayer();

    // 播放状态变化处理
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
          // 资源释放时关闭文件描述符，防止内存泄漏
          if (this.currentPlaySource) {
            this.fileService.closeFileFd(this.currentPlaySource.fd);
            this.currentPlaySource = null;
          }
          break;
      }
    };

    // 播放错误处理：重置状态并释放文件资源
    this.playerService.onError = (error: BusinessError) => {
      this.isPlaying = false;
      this.message = '播放出错: ' + error.message;
      if (this.currentPlaySource) {
        this.fileService.closeFileFd(this.currentPlaySource.fd);
        this.currentPlaySource = null;
      }
    };

    // 总时长更新回调
    this.playerService.onDurationUpdate = (duration: number) => {
      this.duration = duration;
    };

    // 播放进度更新：仅非拖拽状态时刷新进度条
    this.playerService.onTimeUpdate = (time: number, duration: number) => {
      if (!this.isDragging) {
        this.currentTime = time;
        this.duration = duration;
        if (duration > 0) {
          this.progressValue = Math.min(100, Math.max(0, (time / duration) * 100));
        }
      }
    };

    // seek 完成：结束拖拽状态
    this.playerService.onSeekDone = () => {
      console.info('跳转完成');
      this.isDragging = false;
    };

    // 缓冲开始：显示 loading
    this.playerService.onBufferingStart = () => {
      this.isBuffering = true;
      this.message = '缓冲中...';
    };

    // 缓冲结束：隐藏 loading，恢复播放状态提示
    this.playerService.onBufferingEnd = () => {
      this.isBuffering = false;
      if (this.isPlaying) {
        this.message = '正在播放...';
      }
    };
  }

  /**
   * 选择本地音频文件并开始播放
   * 流程：系统文件选择器 → 转换为 fd:// 路径 → 设置播放源
   */
  async selectAndPlay(): Promise<void> {
    const uri = await this.fileService.selectLocalFile();
    if (!uri) {
      this.message = '未选择文件';
      return;
    }

    this.currentFileName = uri.split('/').pop() || '未知文件';
    this.message = `正在加载: ${this.currentFileName}`;

    // 先关闭旧文件描述符，防止泄漏
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

  /**
   * 播放/暂停切换
   * 根据当前状态决定调用 play / pause / 重新设置播放源
   */
  async togglePlayPause(): Promise<void> {
    if (this.isPlaying) {
      await this.playerService.pause();
    } else {
      if (this.playerState === 'paused') {
        await this.playerService.play();
      } else if (this.playerState === 'completed' || this.playerState === 'stopped' || this.playerState === 'idle') {
        if (this.lastStreamUrl) { this.playerService.setUrl(this.lastStreamUrl); }
        else if (this.currentPlaySource) { this.playerService.setUrl(this.currentPlaySource.fdUrl); }
      }
    }
  }

  /**
   * 播放网络流 URL（网易云在线播放）
   * 直接设置 https:// 地址，状态机自动触发 initialized → prepared → playing
   */
  async playStreamUrl(url: string): Promise<void> {
    if (!url) { this.message = '获取播放地址失败'; return; }
    this.message = '正在连接...';
    // 切歌：先停止当前播放，再设置新源
    await this.stopCurrentIfNeeded();
    this.lastStreamUrl = url;
    this.playerService.setUrl(url);
    this.isPlayed = true;
  }

  /** 播放需鉴权的流（B站 CDN 需 Referer） */
  async playStreamUrlWithHeaders(url: string, headers: Record<string, string>): Promise<void> {
    if (!url) { this.message = '获取播放地址失败'; return; }
    this.message = '正在连接...';
    await this.stopCurrentIfNeeded();
    this.lastStreamUrl = url;
    this.playerService.setUrlWithHeaders(url, headers);
    this.isPlayed = true;
  }

  // 如果正在播放，先停止并重置到 idle，确保能干净设置新 URL
  private async stopCurrentIfNeeded(): Promise<void> {
    if (this.playerState === 'idle' || this.playerState === 'released') return;
    try {
      await this.playerService.stop();
      await this.playerService.reset();
    } catch (e) {
      // reset 可能失败（如 released 状态），忽略
    }
  }

  // 毫秒 → mm:ss 格式化
  formatTime(milliseconds: number): string {
    if (milliseconds <= 0) return '00:00';
    const totalSeconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
  }

  // 跳转到指定时间位置（供 PlayerPage 的 Slider 使用）
  async seek(targetTime: number): Promise<void> {
    await this.playerService.seek(targetTime);
  }

  // 进度条拖拽开始：锁定进度更新，避免 timeUpdate 覆盖拖拽值
  onDragStart(): void {
    this.isDragging = true;
  }

  // 进度条拖拽中：实时更新进度和预览时间
  onDragMove(value: number): void {
    if (!this.isDragging) return;
    this.progressValue = value;
    const targetTime = (value / 100) * this.duration;
    this.currentTime = targetTime;
  }

  /**
   * 进度条拖拽结束
   * - 拖到末尾（≥98%）触发播放完成逻辑
   * - 有效状态内执行 seek 跳转
   * - completed 状态拖拽时重新设置播放源再 seek
   */
  async onDragEnd(value: number): Promise<void> {
    // 拖拽到末尾（超过98%），自动触发完成状态
    if (value >= 98 && this.duration > 0) {
      console.info('拖拽到视频末尾，触发完成状态');
      this.isDragging = false;
      this.playerState = 'completed';
      this.isPlaying = false;
      this.message = '播放完成，已重置';
      await this.playerService.reset();
      this.currentTime = this.duration;
      this.progressValue = 100;
      return;
    }

    // 检查播放器是否处于可跳转的状态
    const validSeekStates = ['playing', 'paused', 'prepared', 'idle'];
    if (!validSeekStates.includes(this.playerState)) {
      console.warn(`当前状态 ${this.playerState} 不支持跳转`);
      this.isDragging = false;

      // completed 状态下拖拽：重新设置播放源后再 seek
      if (this.playerState === 'completed' && this.currentPlaySource) {
        console.info('从完成状态重新开始播放');
        this.playerService.setUrl(this.currentPlaySource.fdUrl);
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

  // 释放所有资源（页面销毁时调用）
  release(): void {
    this.playerService.release();
  }

  // 是否有当前播放源（用于启用/禁用播放按钮）
  hasCurrentPlaySource(): boolean {
    return !!this.currentPlaySource;
  }
}
