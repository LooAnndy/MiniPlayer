/**
 * 全屏播放详情页 —— 对齐 UI_STRUCTURE.md §3.7 FavoriteMusicPage
 * 黑胶唱片沉浸播放体验：模糊封面背景、唱针动画、旋转唱片、播放控制
 */
import { Song } from '../model/Song';
import PlayerViewModel from '../viewmodel/PlayerViewModel';
import router from '@ohos.router';

@Entry
@ComponentV2
export struct PlayerPage {
  @Param viewModel: PlayerViewModel = new PlayerViewModel();
  @Local currentSong?: Song;
  @Local playlist: Song[] = [];
  @Local currentIndex: number = 0;
  @Local showPlaylist: boolean = false;

  // 动画控制
  @Local diskRotation: number = 0;   // 唱片旋转角度
  @Local needleAngle: number = -30;  // 唱针角度（0=落下播放，-30=抬起暂停）
  @Local sliderValue: number = 0;
  @Local isDragging: boolean = false;
  private rotationTimer?: number;

  aboutToAppear(): void {
    this.viewModel.initPlayer();
    this.updateSliderValue();
  }

  aboutToDisappear(): void {
    this.viewModel.release();
    this.stopDiskRotation();
  }

  build() {
    Stack() {
      // 背景：模糊封面 + 30% 黑色遮罩
      Column() {
        Image(this.currentSong?.coverUrl || $r('app.media.default_cover'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .blur(30)
          .brightness(0.3)
      }
      .width('100%')
      .height('100%')

      // 主内容区
      Column() {
        // 顶部导航栏
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
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        // 唱片区域（唱针 + 唱片 + 旋转封面）
        Column({ space: 0 }) {
          // 唱针（播放时落下 0°，暂停时抬起 -30°）
          Row() {
            Text('💿')
              .fontSize(40)
              .rotate({ angle: this.needleAngle })
              .offset({ x: 40, y: 0 })
          }
          .width('100%')
          .height(30)
          .justifyContent(FlexAlign.Center)

          // 唱片圆盘 + 旋转封面（对齐文档 SongCard）
          Stack({ alignContent: Alignment.Center }) {
            // CD 底盘
            Circle()
              .width(260)
              .height(260)
              .fill('#33333344')

            // 唱片纹理环
            Circle()
              .width(240)
              .height(240)
              .fill(Color.Transparent)
              .rotate({ angle: this.diskRotation })

            // 封面（圆角方形，居中置于唱片上）
            Image(this.currentSong?.coverUrl || $r('app.media.default_cover'))
              .width(130)
              .height(130)
              .borderRadius(16)
              .objectFit(ImageFit.Cover)
              .rotate({ angle: this.diskRotation })
              .shadow({ radius: 20, color: '#33000000' })
          }
          .width(280)
          .height(280)
        }
        .width('100%')
        .padding({ top: 20, bottom: 20 })

        // 歌曲信息
        Column({ space: 6 }) {
          Text(this.currentSong?.title || this.viewModel.currentFileName || '未播放')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.currentSong?.artist || '未知歌手')
            .fontSize(16)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .maxLines(1)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')
        .padding({ left: 20, right: 20 })

        // 进度条 + 播放控制（对齐文档 PlayerActionView）
        Column({ space: 12 }) {
          // 进度条行
          Row({ space: 12 }) {
            Text(this.viewModel.formatTime(this.viewModel.currentTime))
              .fontSize(13)
              .fontColor('rgba(255, 255, 255, 0.7)')
              .width(44)

            Slider({
              value: this.sliderValue,
              min: 0,
              max: 100,
              step: 0.1
            })
              .layoutWeight(1)
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
                  const targetTime = Math.floor((value / 100) * this.viewModel.duration);
                  this.viewModel.seek(targetTime);
                }
              })

            Text(this.viewModel.formatTime(this.viewModel.duration))
              .fontSize(13)
              .fontColor('rgba(255, 255, 255, 0.7)')
              .width(44)
          }
          .width('100%')

          // 播放控制按钮组：循环 / 上一首 / 播放暂停 / 下一首 / 播放列表
          Row({ space: 40 }) {
            // 循环模式
            Button() {
              Image($r('sys.media.ohos_ic_public_play_next'))
                .width(22)
                .height(22)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(36)
            .height(36)

            // 上一首
            Button() {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(28)
                .height(28)
                .fillColor(Color.White)
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)

            // 播放/暂停（圆形主按钮）
            Button() {
              Image(this.viewModel.isPlaying ? $r('sys.media.ohos_ic_public_pause') : $r('sys.media.ohos_ic_public_play'))
                .width(40)
                .height(40)
                .fillColor('#C20C0C')
            }
            .type(ButtonType.Circle)
            .backgroundColor(Color.White)
            .width(64)
            .height(64)
            .onClick(() => {
              this.viewModel.togglePlayPause();
              this.updateNeedleAnimation();
            })

            // 下一首
            Button() {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(28)
                .height(28)
                .fillColor(Color.White)
                .rotate({ angle: 180 })
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(44)
            .height(44)

            // 播放列表
            Button() {
              Image($r('sys.symbol.music_note_list'))
                .width(22)
                .height(22)
                .fillColor('rgba(255, 255, 255, 0.7)')
            }
            .type(ButtonType.Normal)
            .backgroundColor(Color.Transparent)
            .width(36)
            .height(36)
            .onClick(() => {
              this.showPlaylist = !this.showPlaylist;
            })
          }
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .height('100%')

      // 播放列表弹出面板
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
                  this.currentSong = this.playlist[index];
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
    }
    .width('100%')
    .height('100%')
  }

  private updateSliderValue(): void {
    if (!this.isDragging && this.viewModel.duration > 0) {
      this.sliderValue = (this.viewModel.currentTime / this.viewModel.duration) * 100;
    }
  }

  // 唱针动画：播放时落下(0°)，暂停时抬起(-30°)
  private updateNeedleAnimation(): void {
    this.needleAngle = this.viewModel.isPlaying ? 0 : -30;
    if (this.viewModel.isPlaying) {
      this.startDiskRotation();
    } else {
      this.stopDiskRotation();
    }
  }

  private startDiskRotation(): void {
    if (this.rotationTimer) return;
    this.rotationTimer = setInterval(() => {
      this.diskRotation = (this.diskRotation + 1) % 360;
    }, 30);
  }

  private stopDiskRotation(): void {
    if (this.rotationTimer) {
      clearInterval(this.rotationTimer);
      this.rotationTimer = undefined;
    }
  }
}
