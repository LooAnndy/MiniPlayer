/**
 * 首页 —— 对齐 UI_STRUCTURE.md §3.4 HomePage 结构
 * 顶部：分段选择器（心动/推荐/音乐/AI写歌 等 8 个子频道）
 * 内容区：横向滑动 Swiper，默认选中"推荐"
 */
import { Song, SegmentItem } from '../model/Song';

// 子频道配置（对齐文档，索引 1 为默认选中"推荐"）
const SEGMENTS: SegmentItem[] = [
  { id: '20025001', name: '心动' },
  { id: '20025002', name: '推荐' },
  { id: '20025003', name: '音乐' },
  { id: '20025006', name: 'AI写歌' },
  { id: '20025007', name: '年报' },
  { id: '20025004', name: '播客' },
  { id: '20025005', name: '听书' },
  { id: '20025008', name: '午夜飞行' }
];

@ComponentV2
export struct HomePage {
  @Event onPlaySong: (song: Song) => void = () => {};

  @Local selectedSegment: number = 1; // 默认选中"推荐"

  build() {
    Column() {
      // 顶部分段选择器（可横向滚动）
      Row({ space: 0 }) {
        Scroll() {
          Row({ space: 26 }) {
            ForEach(SEGMENTS, (segment: SegmentItem, index: number) => {
              Column({ space: 6 }) {
                Text(segment.name)
                  .fontSize(index === this.selectedSegment ? 18 : 15)
                  .fontWeight(index === this.selectedSegment ? FontWeight.Bold : FontWeight.Normal)
                  .fontColor(index === this.selectedSegment ? '#C20C0C' : '#8E8E93')
                  .padding({ left: 16, right: 16 })

                // 指示器（选中项底部红色线条）
                if (index === this.selectedSegment) {
                  Rect()
                    .width(20)
                    .height(3)
                    .radius(1.5)
                    .fill('#C20C0C')
                } else {
                  Row()
                    .width(20)
                    .height(3)
                }
              }
              .onClick(() => {
                this.selectedSegment = index;
                this.onSegmentChange(index);
              })
            })
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })
      .backgroundColor(Color.White)

      // 内容区（Swiper 横向滑动切换子频道）
      Swiper() {
        ForEach(SEGMENTS, (segment: SegmentItem, index: number) => {
          this.buildSegmentContent(index)
        })
      }
      .index(this.selectedSegment)
      .loop(false)
      .indicator(false)
      .duration(250)
      .curve(Curve.EaseOut)
      .layoutWeight(1)
      .onChange((index: number) => {
        this.selectedSegment = index;
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6F9')
  }

  // 子频道内容 Builder
  @Builder
  buildSegmentContent(index: number) {
    if (index === 1) {
      // "推荐"频道：包含几个推荐模块
      Scroll() {
        Column({ space: 16 }) {
          // 推荐入口区
          this.buildRecommendSection()
          // 场景歌单区
          this.buildSceneSection()
          // 专属歌单区
          this.buildPersonalSection()
        }
        .padding(16)
      }
      .scrollBar(BarState.Off)
    } else if (index === 0) {
      // "心动"频道：点击进入全屏播放页
      this.placeholderSegment('心动模式', '黑胶唱片沉浸播放', true)
    } else if (index === 3) {
      this.placeholderSegment('AI写歌', 'DeepSeek 辅助创作')
    } else {
      this.placeholderSegment(SEGMENTS[index].name, '施工中...')
    }
  }

  // 推荐入口区 Builder（对齐文档 RecommendView）
  @Builder
  buildRecommendSection() {
    Column({ space: 12 }) {
      Text('推荐')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .width('100%')

      Row({ space: 12 }) {
        Scroll() {
          Row({ space: 12 }) {
            // 推荐入口卡片列表
            ForEach(['每日推荐', '漫游', '歌单推荐', '私人雷达', '心动模式', '每日博客'], (name: string, i: number) => {
              Column({ space: 6 }) {
                Stack() {
                  Image($r('app.media.default_cover'))
                    .width(140)
                    .height(140)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)

                  // 左上角标签
                  Text(name)
                    .fontSize(12)
                    .fontColor(Color.White)
                    .fontWeight(FontWeight.Bold)
                    .padding({ left: 8, top: 8 })
                    .position({ x: 0, y: 0 })
                }
                .width(140)
                .height(140)

                Text(name)
                  .fontSize(13)
                  .maxLines(1)
                  .width(140)
              }
            })
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
    }
    .width('100%')
  }

  // 场景歌单区 Builder
  @Builder
  buildSceneSection() {
    Column({ space: 12 }) {
      Row() {
        Text('场景歌单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('更多 >')
          .fontSize(13)
          .fontColor('#8E8E93')
      }
      .width('100%')

      Text('专属你的"治愈"精选')
        .fontSize(13)
        .fontColor('#999999')

      Row({ space: 12 }) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach([1, 2, 3, 4, 5], (item: number) => {
              Column({ space: 4 }) {
                Image($r('app.media.default_cover'))
                  .width(140)
                  .height(140)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)

                Text('歌单名称')
                  .fontSize(12)
                  .maxLines(1)
                  .width(140)
              }
            })
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
    }
    .width('100%')
  }

  // 专属歌单区 Builder
  @Builder
  buildPersonalSection() {
    Column({ space: 12 }) {
      Row() {
        Text('专属歌单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text('更多 >')
          .fontSize(13)
          .fontColor('#8E8E93')
      }
      .width('100%')

      Row({ space: 12 }) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach([1, 2, 3, 4], (item: number) => {
              Column({ space: 4 }) {
                Image($r('app.media.default_cover'))
                  .width(140)
                  .height(140)
                  .borderRadius(12)
                  .objectFit(ImageFit.Cover)

                Text('专属推荐')
                  .fontSize(12)
                  .maxLines(1)
                  .width(140)
              }
            })
          }
        }
        .scrollBar(BarState.Off)
        .scrollable(ScrollDirection.Horizontal)
      }
    }
    .width('100%')
  }

  // 占位子频道 Builder
  @Builder
  placeholderSegment(title: string, desc: string, isMusicPlayer: boolean = false) {
    Column({ space: 16 }) {
      if (isMusicPlayer) {
        // 心动模式：简化的唱片播放界面
        Image($r('app.media.default_cover'))
          .width(200)
          .height(200)
          .borderRadius(100)
          .objectFit(ImageFit.Cover)
          .shadow({ radius: 30, color: '#44000000', offsetX: 0, offsetY: 10 })
      } else {
        Image($r('sys.media.ohos_ic_public_drawer_close_filled'))
          .width(80)
          .height(80)
          .fillColor('#E0E0E0')
      }

      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)

      Text(desc)
        .fontSize(14)
        .fontColor('#999999')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 子频道切换回调（占位 —— 后续接入各频道真实数据源）
  private onSegmentChange(index: number): void {
    console.info(`Segment changed to: ${SEGMENTS[index].name}`);
  }
}
