# 独立词条的本地资源

死灵与 HCM 提供相同的资源接口，每个词条仍独立保存自己的 JSON、Lua 和资源。词条使用外部图形资源时，另行安装 SimpleAssets，并排在管理器之前加载。适配层使用 SimpleAssets v2 接口；普通词条和 `ctx:resource()` 不依赖它。

管理器负责声明校验、资源快照、并发复用、字体别名和使用者的生命周期，SimpleAssets 负责原生加载。安装包不包含 SimpleAssets 的代码、DLL 或示例素材。这是词条包的资源管理接口，并非独立的底层加载器，也没有声称加载速度优于 SimpleAssets。

## 声明与加载图片

将 `package-examples/lua-asset-mortis-example` 或 `lua-asset-conditions-example` 放入对应管理器的 `diy/packages`。每个示例只有一个词条，并带一张原创测试图片；选择该词条后会测试加载并记录成功或失败。示例不会添加 HUD 或改变战斗属性，图片是验证接口用的测试素材。

将清单的 API 最低次版本设为 1，并添加资源声明：

```json
"api": {"major": 1, "min_minor": 1},
"assets": [
  {"id": "badge", "type": "texture", "path": "resources/badge.png"}
]
```

同时把 `resources/badge.png` 列入 `files`。资源名称只在本词条包内使用。路径必须准确对应 `resources/` 中已声明的文件；绝对路径、越界路径、目录链接和有歧义的原生资源名称会被拒绝。类型与小写扩展名在加载前校验，每包最多声明 64 项资源。光标热点必须为非负整数，是否超出图片尺寸由加载器检查；动画必须同时声明同名 `.bones` 文件。

Lua 入口使用 `api_version = {major=1, minor=1}`，回调中可以这样请求：

```lua
on_activate = function(ctx)
    local handle, why = ctx:load_asset("badge", function(asset, load_error)
        if not asset then
            ctx:log(load_error)
            return
        end
        ctx.state.badge = asset.texture
        -- 加载成功后，交给支持此贴图的原生 UI 材质。
    end)
    if not handle then ctx:log(why) end
end
```

回调参数为 `(资源结果, 错误)`。命中缓存或立即失败时，回调可能在 `load_asset` 返回前执行。每个成功结果都是独立的浅拷贝表，修改字段不会污染其他使用者的结果。加载中的句柄不能当作已就绪资源使用。

| 操作 | 结果 |
| --- | --- |
| `ctx:load_asset(id, callback?)` | 返回句柄；请求本身不合法时返回 nil／错误。同一绑定重复请求相同 ID 会复用句柄。 |
| `handle:status()` | 返回 `pending`、`ready`、`failed` 或 `cancelled`，以及错误。 |
| `handle:get()` | 就绪结果或 nil／错误，不返回半成品。 |
| `handle:cancel()`／`ctx:release_asset(id)` | 释放本使用者并屏蔽后续回调，不影响其他使用者。 |
| 释放后重新加载 | 重试失败的请求，失败结果不会永久占据成功缓存。 |
| `ctx:on_cleanup(fn)` | 在词条资源作用域关闭前，清理自己创建的原生对象。 |

缺少加载器或解码失败会记录错误，独立的 JSON 效果仍可运行。资源回调自身发生 Lua 错误时，会停止该脚本绑定并清理。词条移除、拥有者死亡、失去权威或任务结束后，未完成的回调不能再追加效果；同步异常与无效加载结果也会被拦截。

## 支持的资源声明

| `type` | 文件 | 成功后使用的字段 |
| --- | --- | --- |
| `texture` | `.png`、`.jpg`、`.jpeg`、`.dds`、已编译 `.texture` | `texture`；普通图片还可能返回宽高 |
| `font` | 已编译 `.slug` 字体 | `font_type`，由管理器生成资源专属别名 |
| `video` | `.ivf` 或 `.bk2` | 交给原生播放器的 `resource_name` |
| `mouse_cursor` | `.png`，另填 `hotspot_x`、`hotspot_y` | `resource_name` |
| `slug_album` | 已编译 `.slug` 图标册 | `resource_name` |
| `material`、`particles`、`unit`、`animation` | 对应扩展名的已编译资源 | `resource_name` |

这些类型对接作者的[资源接口](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/api/engine-resources.md)与[路径／格式约定](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/getting-started/paths.md)。引擎资源必须预先编译到当前游戏版本。所需 `.bones`、`.texture.stream` 等伴随文件也放在 `resources/` 中并列入 `files`，管理器会一起保留。已编译文件内嵌的路径不会被改写，引用的依赖不会自动加载。接口不转换 FBX／Blender、TTF／OTF、MP4、MP3 或 WAV，也不因为支持视频就支持音轨与透明通道。全局 `replace_*` 替换操作不属于此作用域接口。

## 客户端界面与 HUD

游戏逻辑仍遵守房主权威规则。本地安装的界面或 HUD 可以在客户端单独打开资源作用域，无须创建游戏逻辑引擎：

```lua
local manager = get_mod("MortisBuffManager") -- 或 HavocConditionManager
local scope, why = manager.diy_api.open_assets("my-entry-package")
if not scope then return end

-- 假设 image_widget 已有接受 texture_map 的图片材质，
-- 且其可见性函数读取 content.asset_ready。
scope:own(function()
    image_widget.content.asset_ready = false
    image_widget.style.image.material_values.texture_map = nil
end)
scope:load("badge", function(asset)
    if asset then
        image_widget.style.image.material_values.texture_map = asset.texture
        image_widget.content.asset_ready = true
    end
end)
-- 将 scope 保存在界面中；销毁界面前调用 scope:close("view_exit")。
```

`open_assets(package_id, active_predicate?)` 固定该作用域打开时的本地配置库快照。新打开的作用域可以读取刷新后的资源；已有作用域与正在运行的游戏逻辑仍保留旧版本。客户端能打开资源不代表该词条已被选中，也不代表房主拥有相同文件。`scope:load`、`scope:release`、`scope:own`、`scope:close` 使用相同的加载与清理规则。可选判定函数返回 false 后，管理器更新会关闭作用域。界面退出时仍应主动关闭，并在控件或渲染器销毁前完成清理。

播放视频时，把 `resource_name` 交给 `UIRenderer.create_video_player`，并在 `scope:own` 登记 `UIRenderer.destroy_video_player`。单位、粒子实例也需要相应的原生销毁函数；使用者还应负责恢复被自己更改的光标。释放句柄不会自动销毁由资源创建的世界对象、播放器或光标状态。

## 缓存与寿命

启动及手动刷新配置库时，管理器在下列位置准备资源副本：

```text
%APPDATA%/Fatshark/Darktide/mods/<管理器名>/assets/diy-cache/<资源哈希>/
```

原始包仍位于 `<管理器名>/diy/packages`。缓存只含资源字节，哈希覆盖排序后的资源路径、内容、伴随文件及类型加载参数；只改光标热点也会生成新原生标识，避免沿用旧热点；只改 Lua 或包元数据时可以复用相同资源目录。已有副本会校验，绝不覆盖。请求资源时不会扫描、复制或重新计算包哈希；SimpleAssets 会在首次加载时读取／解码资源。建议在词条激活或界面进入时请求，并保留句柄使用。

游戏中修改源文件不会替换本局副本；刷新后的内容得到新目录与原生标识。死灵的全房间指纹仍覆盖清单、Lua、资源及依赖闭包，不通过网络发送资源字节、代码或使用者句柄。

每个管理器最多允许 256 个打开的作用域、256 条成功或待完成的原生资源记录；每个句柄最多有 16 个待执行回调，每个作用域最多登记 64 个清理回调。未完成请求在累计管理器更新时间达到 35 秒后失败。磁盘缓存最多 128 MiB、256 份资源快照，原来的包大小与单文件限制仍适用。这些限制针对管理记录与源文件，并非显存预算；解码后的贴图和引擎资源可能比源文件大得多。

已检查的加载器没有通用的单资源卸载接口，因此成功的原生加载结果在进程内复用。关闭使用者会屏蔽回调并执行登记的清理，不承诺释放原生贴图、字体等底层分配。视频可能持续读取文件，因此缓存不会在任务结束时删除。缓存满或内容被修改时，请先退出游戏，仅删除上述目录中的本管理器 `assets/diy-cache`，再重新启动；不要把源包目录 `diy/packages` 当缓存删除。更换或重新加载 SimpleAssets 后应重启游戏。

## 验证范围

离线检查覆盖九种加载接口的参数、隔离环境中的真实 Windows Unicode 缓存 IO、伴随文件、内容变化、缓存篡改拒绝、磁盘／请求限制、并发复用、重试、超时、取消及回调错误。实际死灵与 HCM 工厂还验证了本局冻结、客户端本地作用域和缺少依赖时的降级。原生加载边界使用替身；实际游戏显示、编译资源兼容性与多人视觉效果仍需实机验收。
