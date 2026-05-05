/**
 * 播放状态中间件 —— PlayerBar / PlayerPage / MainPage 共享
 * 所有播放控制操作统一经由此处，避免跨页面状态不同步
 */
import PlayerViewModel from '../viewmodel/PlayerViewModel';
import { Song, Platform } from '../model/Song';

class PlayerStateCenter {
  viewModel: PlayerViewModel = new PlayerViewModel();
  currentSong: Song = {
    id: 0, name: '', title: '', artist: '', album: '',
    duration: 0, coverUrl: '', audioUrl: '', platform: Platform.LOCAL
  };

  // ====== 初始化 ======

  async init(): Promise<void> {
    await this.viewModel.initPlayer();
  }

  release(): void {
    this.viewModel.release();
  }

  // ====== 播放控制（直接操作 state，PlayerBar 自动同步） ======

  /** 暂停 */
  async pause(): Promise<void> {
    await this.viewModel.pause();
  }

  /** 继续播放 */
  async play(): Promise<void> {
    await this.viewModel.play();
  }

  /** 播放/暂停切换 */
  async togglePlayPause(): Promise<void> {
    if (this.viewModel.isPlaying) {
      await this.pause();
    } else {
      await this.play();
    }
  }

  /** 播放流地址 */
  async playStreamUrl(url: string): Promise<void> {
    await this.viewModel.playStreamUrl(url);
  }

  /** 跳转到指定时间 */
  async seek(time: number): Promise<void> {
    await this.viewModel.seek(time);
  }

  /** 设置当前歌曲 */
  setCurrentSong(song: Song): void {
    this.currentSong = song;
    this.viewModel.isPlayed = true;
  }
}

export const playerState = new PlayerStateCenter();
