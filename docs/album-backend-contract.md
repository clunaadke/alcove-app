# 相册前后端对接（原生前端已实现，后端待接）

代码：`AlbumModels.swift`、`AlbumView.swift`、`AlbumCards.swift`。
基址和网络会话复用 `AlcoveAPI`。本文是前端实际使用的协议，不代表服务器已有这些接口。
接口使用现有鉴权机制；不要在客户端写入新的密钥。

## 页面与流程

- 侧边栏「记忆与创作 → 相册」打开全屏原生页面，有图库、相簿、搜索和筛选。
- 相簿支持封面、数量、新建、长按重命名；大图详情可编辑备注、移动分类。
- 用户从相册上传：每次一张，选图＋一句话＋分类；成功后刷新相册，不发送聊天消息。
- 此上传先转换为最长边 4096px 的 JPEG（质量 0.9），服务器接收的是这份标准化图片，并非相机原始 HEIC。不会调用现有 `/api/upload`，避免意外唤醒助手。
- 聊天收藏：由后端工具决定，完成持久保存后投递卡片。前端不自动收藏普通聊天图片。
- 卡片小图＋“他往『分类』里存了 N 张照片”；点击打开圆角正方形卡片。
- 同批次第一张占大图，后续小图排列；超过四张显示余量。所有照片均可在大图页左右切换，查看各自备注。
- 同批次可有公共 caption；未提供时显示当前选中照片的 caption。分类按照片保存，可跨分类。
- 后端不可用时显示失败和重试，前端没有演示照片或模拟“已保存”。

## JSON 约定

所有 ID 都是字符串；时间用 ISO-8601。以下 photo 是上传、列表、编辑和历史卡片共用结构：

```json
{
  "photo_id": "photo_001",
  "original_url": "/api/album/media/photo_001.jpg",
  "thumbnail_url": "/api/album/media/photo_001_thumb.jpg",
  "caption": "今天窗外的雨。",
  "category_id": "daily",
  "category_name": "日常",
  "uploaded_by": "user",
  "source": "album_upload",
  "created_at": "2026-09-11T10:00:00Z",
  "post_status": "unused",
  "posts": []
}
```

必须提供 `photo_id`、`original_url`。其余字段可为空，但应完整提供，保证分类、备注和发布状态准确显示。未分类使用 `category_id: null`、`category_name: "未分类"`。

`uploaded_by`: `user` / `assistant`；`source`: `album_upload` / `assistant_upload` / `chat_saved`。
聊天收藏中 `uploaded_by` 是原图上传者，`source` 标明由聊天收藏，不混淆这两个字段。
`post_status`: `unused` / `reserved` / `posted` / `unknown`。不确定状态不能当未发过。
`posts`: `[{"post_id":"x123","published_at":"...","url":"https://..."}]`。

图片 URL 可为站内路径或 HTTP(S) 地址。优先返回受现有访问控制保护的稳定站内路径，由服务端解析实际存储位置；历史卡片不能依赖会过期的签名 URL。旧 `/attachments/...` 会沿用客户端现有映射。原图、缩略图应支持同样的访问方式。

分类结构：

```json
{"category_id":"daily","name":"日常","count":12,"cover_url":"/api/album/media/cover.jpg"}
```

## 接口清单

| 请求 | 输入 | 成功响应 |
|---|---|---|
| GET `/api/album/categories` | 无 | `{"categories":[category]}` |
| POST `/api/album/categories` | JSON `{"name":"日常"}` | `{"category":category}` |
| PATCH `/api/album/categories` | JSON `{"category_id":"daily","name":"我们的日常"}` | `{"category":category}` |
| GET `/api/album/photos` | 查询 `limit=60&filter=all`，可选 `category_id`、`q`、`cursor` | `{"photos":[photo],"next_cursor":null}` |
| POST `/api/album/upload` | multipart，见下方 | `{"photo":photo}` |
| PATCH `/api/album/photos` | JSON `{"photo_id":"photo_001","caption":"新备注","category_id":"daily"}` | `{"photo":photo}` |

列表按保存时间倒序。`next_cursor` 为不透明游标，到末页返回 null；分类、搜索和 filter 应组合过滤，翻页保持稳定。filter 的取值：

- `all`：全部。
- `user` / `assistant`：按原上传者。
- `chat_saved`：聊天收藏来源。
- `unused`：明确未发布、未占用且结果无疑义的照片。
- `posted`：已有成功发帖记录。

上传 multipart 字段：`file`（photo.jpg，image/jpeg）、`caption`、可选 `category_id`、`source=album_upload`、`notify_assistant=false`、`index_memory=true`。
请求头 `Idempotency-Key: <UUID>`。同一次请求失败重试使用相同 ID 和相同内容，后端若已经完成保存需返回同一条记录，不能再次保存。这个端点应固定静默行为，不只依靠客户端布尔值。严禁转到聊天上传接口。

非 2xx 不能伪装成功。404/501/503 在前端显示暂时无法连接；401/403 显示访问失败；413 提示图片过大。索引异步重试与图片保存分开处理，图片已落库即可返回成功。

## 聊天保存卡片（关键）

复用现有 `/api/history`、`/api/poll` 的卡片消息格式。消息 role 必须是 assistant，text 必须是完整标记，不能与普通文本拼在同一条：

```text
[ALBUM_SAVED]{"event_id":"save_event_01","batch_id":"save_batch_01","status":"saved","assistant_name":"陈璟","caption":"这几张，我想放在一起。","photos":[{"photo_id":"photo_001","original_url":"/api/album/media/photo_001.jpg","thumbnail_url":"/api/album/media/photo_001_thumb.jpg","caption":"今天窗外的雨。","category_id":"daily","category_name":"日常","post_status":"unused"}]}[/ALBUM_SAVED]
```

- 持久保存完成后发送；`status` 必须为 `saved`。空批次、缺 ID、重复 photo_id、pending/failed 不渲染成功卡片。
- 同次连续收藏由后端确定 batch_id，不能让前端通过相邻时间猜测。
- 推荐一批全部成功后只投递一次最终卡片，`photos` 带完整有序照片列表。首项决定大图。
- 允许部分成功时只列出实际存好的照片，失败照片不得混入成功卡片。
- 一批只写一条聊天记录。重试沿用 event_id、batch_id；历史和轮询保持同一 ts 和 role，现有聊天去重依赖它们。如更新同批卡片，修改原记录的 text 并重新推送同一 ts，不追加新记录。
- 普通话语“我存了”不会触发卡片。用户静默上传不生成这条聊天卡片。
- 备注作者、原聊天消息关联、记忆索引 ID 等额外后台字段可增加；前端会忽略未知字段。

## 后端仍需完成

1. 持久原图、缩略图、分类、备注、图片哈希去重。收藏聊天临时图时提升为持久存储。
2. 给助手提供上传、收藏聊天图片、搜索/浏览相册、打开原图工具。
3. LMC 索引关联 photo_id；备注、图像描述和来源分开存。召回带可打开的照片引用，不只返回一句话；修改/删除同步索引，索引失败可重试。
4. 发帖只查询明确 unused 的图片；选图原子占用；成功保存帖子 ID/时间再标记 posted；失败释放，结果不明先核实；无合适新图则不配图。不要自动重复发旧图。
5. 执行实际联调：静默上传不触发聊天；同批多图只生成一张卡；断网重试不重复；退出重开有历史卡片；分页分类不混图；成功发帖后从未发过筛选消失。

## 验证

macOS 可运行：

```sh
swiftc ios/App/App/NativeChat/AlbumModels.swift scripts/album-tests/main.swift -o /tmp/album-tests
/tmp/album-tests
```

测试使用实际数据模型，覆盖成功/失败事件、单图/多图顺序、重复 ID、URL 和查询编码、发帖标记。完整 App 编译由现有 Build Unsigned IPA 工作流执行。
