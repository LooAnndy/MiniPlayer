/**
 * 下载管理页面（第二阶段）
 * 展示正在下载和已下载的音乐列表
 * 后续将接入 DownloadService 实现真正的下载功能
 */
import { Song } from '../model/Song';

@ComponentV2
export struct DownloadPage {
  @Local downloadedSongs: Song[] = [];
  @Local downloadingSongs: Song[] = [];
  @Local totalSize: number = 0;

  build() {
    Column({ space: 16 }) {
      // 顶部标题栏：标题 + 已用存储空间
      Row() {
        Text('下载管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)

        Blank()

        Text(`已用: ${this.formatSize(this.totalSize)}`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')
      .padding(20)

      // 下载中列表
      if (this.downloadingSongs.length > 0) {
        Column({ space: 12 }) {
          Text('下载中')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)

          Column({ space: 8 }) {
            ForEach(this.downloadingSongs, (song: Song, index: number) => {
              Row({ space: 12 }) {
                Image(song.coverUrl || $r('app.media.default_cover'))
                  .width(50)
                  .height(50)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)

                Column({ space: 4 }) {
                  Text(song.title)
                    .fontSize(14)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(140)

                  Row({ space: 8 }) {
                    Text('下载中...')
                      .fontSize(12)
                      .fontColor('#FF9800')

                    Text('45%')
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Button('暂停')
                  .fontSize(12)
                  .backgroundColor('#FFF3E0')
                  .fontColor('#FF9800')
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(Color.White)

              // 下载进度条
              Progress({
                value: 45,
                total: 100,
                type: ProgressType.Linear
              })
                .width('100%')
                .height(3)
                .color('#FF9800')
                .backgroundColor('#F0F0F0')
            })
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20 })
      }

      // 已下载列表
      Column({ space: 12 }) {
        Text('已下载')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)

        if (this.downloadedSongs.length > 0) {
          Column({ space: 8 }) {
            ForEach(this.downloadedSongs, (song: Song, index: number) => {
              Row({ space: 12 }) {
                Image(song.coverUrl || $r('app.media.default_cover'))
                  .width(50)
                  .height(50)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)

                Column({ space: 4 }) {
                  Text(song.title)
                    .fontSize(14)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(140)

                  Text(`${song.artist} - ${song.album}`)
                    .fontSize(12)
                    .fontColor('#999999')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width(140)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column({ space: 8 }) {
                  Text('5.2 MB')
                    .fontSize(12)
                    .fontColor('#999999')

                  Text('已下载')
                    .fontSize(12)
                    .fontColor('#4CAF50')
                }
              }
              .width('100%')
              .padding(12)
              .borderRadius(12)
              .backgroundColor(Color.White)
            })
          }
        } else {
          // 空状态：暂无下载
          Column({ space: 16 }) {
            Image($r('sys.media.ohos_save_button_filled'))
              .width(80)
              .height(80)
              .fillColor('#E0E0E0')

            Text('暂无下载')
              .fontSize(16)
              .fontColor('#999999')

            Text('点击歌曲右侧更多按钮下载')
              .fontSize(14)
              .fontColor('#CCCCCC')
          }
          .width('100%')
          .height(200)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FAFAFA')
  }

  // 字节 → 可读的文件大小格式
  private formatSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
  }
}
