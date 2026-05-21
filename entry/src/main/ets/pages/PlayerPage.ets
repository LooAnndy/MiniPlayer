/**
 * 全屏播放详情页
 * 布局对齐 FEATURE_ANALYSIS.md：
 *   模糊封面背景、方形封面（MusicInfoComponent）、收藏按钮、
 *   功能图标栏 + 进度条 + 播放控制（ControlAreaComponent）
 */
import { Song } from '../model/Song';
import { playerViewModel } from '../viewmodel/PlayerViewModel';
import { Router, UIContext } from '@kit.ArkUI';

@Entry
@ComponentV2
export struct PlayerPage {
  @Local playlist: Song[] = [];
  @Local currentIndex: number = 0;
  @Local showPlaylist: boolean = false;

  // 进度控制
  @Local sliderValue: number = 0;
  @Local isDragging: boolean = false;

  // 功能图标状态（对齐 ControlAreaComponent 5 个功能图标）
  @Local playMode: number = 0;        // 0=ORDER, 1=RANDOM, 2=SINGLE_CYCLE
  @Local isFavorite: boolean = false;
  @Local isSilentMode: boolean = false;
  @Local playbackSpeed: number = 1;
  @Local volume: number = 80;
  @Local showSpeedPanel: boolean = false;
  @Local showVolumePanel: boolean = false;

  aboutToAppear(): void {
    this.updateSliderValue();
  }

  build() {
    Stack() {
      // 背景：纯暗色底，图标可见性优先

      // 主内容区
      Column() {
        // ========== 顶部导航栏 ==========
        Row() {
          Button() {
            Image($r('sys.media.ohos_ic_public_arrow_left'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            const uiContext: UIContext = this.getUIContext();
            const router: Router = uiContext.getRouter();
            if (router.getStackSize() <= 1) {
              console.warn('PlayerPage: No previous page to go back to.');
              return;
            }
            router.back();
          })

          Text('正在播放')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button() {
            Image($r('sys.media.ohos_ic_public_more'))
              .width(24)
              .height(24)
              .fillColor(Color.White)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 30, bottom: 12 })

        // ========== 封面图：方形、圆角、阴影 + 缓冲 loading 叠加
        Stack() {
          Image(playerViewModel.currentSong?.coverUrl || $r('app.media.default_cover'))
            .width(280)
            .aspectRatio(1)
            .borderRadius(16)
            .objectFit(ImageFit.Cover)
            .shadow({ radius: 20, color: '#33000000', offsetY: 8 })

          if (playerViewModel.isBuffering) {
            Column({ space: 8 }) {
              LoadingProgress()
                .width(36)
                .height(36)
                .color(Color.White)
              Text('缓冲中...')
                .fontSize(12)
                .fontColor('rgba(255, 255, 255, 0.8)')
            }
            .width(280)
            .aspectRatio(1)
            .borderRadius(16)
            .justifyContent(FlexAlign.Center)
            .backgroundColor('rgba(0, 0, 0, 0.5)')
          }
        }

        // ========== 歌曲信息 + 收藏按钮
        Row({ space: 12 }) {
          Column({ space: 6 }) {
            Text(playerViewModel.currentSong?.title || playerViewModel.currentFileName || '未播放')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')

            Text(playerViewModel.currentSong?.artist || '未知歌手')
              .fontSize(16)
              .fontColor('rgba(255, 255, 255, 0.8)')
              .maxLines(1)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          // 收藏按钮
          Button() {
            Image(this.isFavorite ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
              .width(24)
              .height(24)
              .fillColor(this.isFavorite ? Color.Red : Color.White)
          }
          .type(ButtonType.Normal)
          .backgroundColor(Color.Transparent)
          .width(40)
          .height(40)
          .onClick(() => {
            this.isFavorite = !this.isFavorite;
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 24 })

        Blank()

        // ========== 底部控制区
        Column({ space: 16 }) {
          // --- 第一行：功能图标（静音、倍速、音量）---
          Row({ space: 0 }) {
            // 静音切换
            Button() {
              Image(this.isSilentMode ? $r('sys.symbol.bell_slash') : $r('sys.symbol.bell'))
                .width(22)
                .height(22)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onClick(() => {
              this.isSilentMode = !this.isSilentMode;
            })

            // 倍速设置
            Button() {
              Image($r('sys.symbol.speed_multiple'))
                .width(22)
                .height(22)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onClick(() => {
              this.showSpeedPanel = !this.showSpeedPanel;
            })

            // 音量设置
            Button() {
              Image(this.getVolumeIcon())
                .width(22)
                .height(22)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
            .onClick(() => {
              this.showVolumePanel = !this.showVolumePanel;
            })
          }
          .width('100%')

          // --- 第二行：进度区域 ---
          Column({ space: 4 }) {
            Slider({
              value: this.sliderValue,
              min: 0,
              max: 100,
              step: 0.1
            })
              .width('100%')
              .trackColor('rgba(255, 255, 255, 0.2)')
              .selectedColor(Color.White)
              .blockColor(Color.White)
              .showSteps(false)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.sliderValue = value;
                if (mode === SliderChangeMode.Begin) {
                  this.isDragging = true;
                } else if (mode === SliderChangeMode.End) {
                  this.isDragging = false;
                  const targetTime = Math.floor((value / 100) * playerViewModel.duration);
                  playerViewModel.seek(targetTime);
                }
              })

            Row({ space: 0 }) {
              Text(playerViewModel.formatTime(playerViewModel.currentTime))
                .fontSize(13)
                .fontColor('rgba(255, 255, 255, 0.7)')

              Blank()

              Text(playerViewModel.formatTime(playerViewModel.duration))
                .fontSize(13)
                .fontColor('rgba(255, 255, 255, 0.7)')
            }
            .width('100%')
          }
          .width('100%')

          // --- 第三行：播放模式 + 播放控制 + 歌单 ---
          // 布局：[播放模式] [上一首] [播放/暂停] [下一首] [歌单]
          Row({ space: 12 }) {
            // 播放模式切换
            Button() {
              Image(this.getPlayModeIcon())
                .width(24)
                .height(24)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(40)
            .height(40)
            .onClick(() => {
              this.playMode = (this.playMode + 1) % 3;
            })

            Blank()

            // 上一首
            Button() {
              Image($r('app.media.ic_public_forward'))
                .width(28)
                .height(28)
                .fillColor(Color.White)
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)

            // 播放/暂停（圆形主按钮，居中）
            Button() {
              Image(playerViewModel.isPlaying ? $r('app.media.ic_play') : $r('app.media.ic_play_all'))
              .width(64)
                .height(64)
                .fillColor('#C20C0C')
            }
            .backgroundColor(Color.Transparent)
            .width(64)
            .height(64)
            .onClick(() => {
              playerViewModel.togglePlayPause();
            })

            // 下一首
            Button() {
              Image($r('app.media.ic_public_next'))
                .width(28)
                .height(28)
                .fillColor(Color.White)
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(48)
            .height(48)

            Blank()

            // 歌单列表
            Button() {
              Image($r('app.media.ic_music_list'))
                .width(24)
                .height(24)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(40)
            .height(40)
            .onClick(() => {
              this.showPlaylist = !this.showPlaylist;
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 20 })
      }
      .width('100%')
      .height('100%')

      // ========== 播放列表弹出面板 ==========
      if (this.showPlaylist) {
        Column() {
          Row() {
            Text('播放列表')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)

            Button() {
              Image($r('sys.symbol.music'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.showPlaylist = false;
            })
          }
          .width('100%')
          .padding(16)

          if (this.playlist.length > 0) {
            List({ space: 0 }) {
              ForEach(this.playlist, (song: Song, index: number) => {
                ListItem() {
                  Row({ space: 12 }) {
                    Text(`${index + 1}`)
                      .fontSize(14)
                      .fontColor('rgba(255, 255, 255, 0.5)')
                      .width(30)

                    Column({ space: 4 }) {
                      Text(song.title)
                        .fontSize(14)
                        .fontColor(this.currentIndex === index ? '#C20C0C' : Color.White)
                        .fontWeight(this.currentIndex === index ? FontWeight.Medium : FontWeight.Normal)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })

                      Text(song.artist)
                        .fontSize(12)
                        .fontColor('rgba(255, 255, 255, 0.6)')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    if (this.currentIndex === index) {
                      Image($r('sys.media.ohos_ic_public_play'))
                        .width(20)
                        .height(20)
                        .fillColor('#C20C0C')
                    }
                  }
                  .width('100%')
                  .padding({ left: 16, right: 16, top: 12, bottom: 12 })
                  .borderRadius(8)
                  .backgroundColor(this.currentIndex === index ? 'rgba(194, 12, 12, 0.2)' : Color.Transparent)
                }
                .onClick(() => {
                  this.currentIndex = index;
                  playerViewModel.currentSong = this.playlist[index];
                  this.showPlaylist = false;
                })
              })
            }
            .layoutWeight(1)
          } else {
            Column({ space: 12 }) {
              Text('播放列表为空')
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.5)')
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('60%')
        .backgroundColor('rgba(0, 0, 0, 0.95)')
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '40%' })
      }

      // ========== 倍速设置面板（对齐倍速 Sheet）==========
      if (this.showSpeedPanel) {
        Column({ space: 16 }) {
          Text('播放速度')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)

          Row({ space: 12 }) {
            Text('0.5x')
              .fontSize(13)
              .fontColor('rgba(255, 255, 255, 0.5)')

            Slider({
              value: this.playbackSpeed,
              min: 0.5,
              max: 2,
              step: 0.25
            })
              .layoutWeight(1)
              .trackColor('rgba(255, 255, 255, 0.2)')
              .selectedColor('#C20C0C')
              .blockColor(Color.White)
              .showSteps(true)
              .showTips(true, this.playbackSpeed.toFixed(2) + 'x')
              .onChange((value: number, mode: SliderChangeMode) => {
                this.playbackSpeed = value;
              })

            Text('2x')
              .fontSize(13)
              .fontColor('rgba(255, 255, 255, 0.5)')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('rgba(0, 0, 0, 0.95)')
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '60%' })
      }

      // ========== 音量设置面板（对齐音量 Sheet）==========
      if (this.showVolumePanel) {
        Column({ space: 16 }) {
          Text('音量')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)

          Row({ space: 12 }) {
            Image($r('sys.symbol.speaker_wave_1'))
              .width(20)
              .height(20)
              .fillColor('rgba(255, 255, 255, 0.5)')

            Slider({
              value: this.volume,
              min: 0,
              max: 100,
              step: 1
            })
              .layoutWeight(1)
              .trackColor('rgba(255, 255, 255, 0.2)')
              .selectedColor('#C20C0C')
              .blockColor(Color.White)
              .showSteps(false)
              .onChange((value: number, mode: SliderChangeMode) => {
                this.volume = value;
                if (value === 0) {
                  this.isSilentMode = true;
                } else if (this.isSilentMode) {
                  this.isSilentMode = false;
                }
              })

            Image($r('sys.symbol.speaker_wave_3'))
              .width(20)
              .height(20)
              .fillColor('rgba(255, 255, 255, 0.5)')
          }
          .width('100%')
        }
        .width('100%')
        .padding(20)
        .backgroundColor('rgba(0, 0, 0, 0.95)')
        .borderRadius({ topLeft: 20, topRight: 20 })
        .position({ x: 0, y: '60%' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#CC000000')
  }

  private updateSliderValue(): void {
    if (!this.isDragging && playerViewModel.duration > 0) {
      this.sliderValue = (playerViewModel.currentTime / playerViewModel.duration) * 100;
    }
  }

  // 循环模式图标：ORDER → 顺序循环 / RANDOM → 随机 / SINGLE_CYCLE → 单曲循环
  private getPlayModeIcon(): Resource {
    if (this.playMode === 1) {
      return $r('app.media.shuffle');
    } else if (this.playMode === 2) {
      return $r('app.media.order_play');
    }
    return $r('app.media.repeat_single_song');
  }

  // 音量图标：0 → 静音 / 1~50 → 低音量 / 51+ → 高音量
  private getVolumeIcon(): Resource {
    if (this.volume === 0 || this.isSilentMode) {
      return $r('sys.symbol.speaker_slash');
    } else if (this.volume <= 50) {
      return $r('sys.symbol.speaker_wave_1');
    }
    return $r('sys.symbol.speaker_wave_3');
  }
}
