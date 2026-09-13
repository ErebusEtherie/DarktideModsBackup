# 獨立詞條的本地資源

死靈與 HCM 提供相同的資源介面，每個詞條仍獨立儲存自己的 JSON、Lua 和資源。詞條使用外部圖形資源時，另行安裝 SimpleAssets，並排在管理器之前載入。適配層使用 SimpleAssets v2 介面；普通詞條和 `ctx:resource()` 不依賴它。

管理器負責宣告校驗、資源快照、併發複用、字型別名和使用者的生命週期，SimpleAssets 負責原生載入。安裝包不包含 SimpleAssets 的程式碼、DLL 或示例素材。這是詞條包的資源管理介面，並非獨立的底層載入器，也沒有聲稱載入速度優於 SimpleAssets。

## 宣告與載入圖片

將 `package-examples/lua-asset-mortis-example` 或 `lua-asset-conditions-example` 放入對應管理器的 `diy/packages`。每個示例只有一個詞條，並帶一張原創測試圖片；選擇該詞條後會測試載入並記錄成功或失敗。示例不會新增 HUD 或改變戰鬥屬性，圖片是驗證介面用的測試素材。

將清單的 API 最低次版本設為 1，並新增資源宣告：

```json
"api": {"major": 1, "min_minor": 1},
"assets": [
  {"id": "badge", "type": "texture", "path": "resources/badge.png"}
]
```

同時把 `resources/badge.png` 列入 `files`。資源名稱只在本詞條包內使用。路徑必須準確對應 `resources/` 中已宣告的檔案；絕對路徑、越界路徑、目錄連結和有歧義的原生資源名稱會被拒絕。型別與小寫副檔名在載入前校驗，每包最多宣告 64 項資源。游標熱點必須為非負整數，是否超出圖片尺寸由載入器檢查；動畫必須同時宣告同名 `.bones` 檔案。

Lua 入口使用 `api_version = {major=1, minor=1}`，回撥中可以這樣請求：

```lua
on_activate = function(ctx)
    local handle, why = ctx:load_asset("badge", function(asset, load_error)
        if not asset then
            ctx:log(load_error)
            return
        end
        ctx.state.badge = asset.texture
        -- 載入成功後，交給支援此貼圖的原生 UI 材質。
    end)
    if not handle then ctx:log(why) end
end
```

回撥引數為 `(資源結果, 錯誤)`。命中快取或立即失敗時，回撥可能在 `load_asset` 返回前執行。每個成功結果都是獨立的淺複製表，修改欄位不會汙染其他使用者的結果。載入中的控制代碼不能當作已就緒資源使用。

| 操作 | 結果 |
| --- | --- |
| `ctx:load_asset(id, callback?)` | 返回控制代碼；請求本身不合法時返回 nil／錯誤。同一繫結重複請求相同 ID 會複用控制代碼。 |
| `handle:status()` | 返回 `pending`、`ready`、`failed` 或 `cancelled`，以及錯誤。 |
| `handle:get()` | 就緒結果或 nil／錯誤，不返回半成品。 |
| `handle:cancel()`／`ctx:release_asset(id)` | 釋放本使用者並遮蔽後續回撥，不影響其他使用者。 |
| 釋放後重新載入 | 重試失敗的請求，失敗結果不會永久佔據成功快取。 |
| `ctx:on_cleanup(fn)` | 在詞條資源作用域關閉前，清理自己建立的原生物件。 |

缺少載入器或解碼失敗會記錄錯誤，獨立的 JSON 效果仍可執行。資源回撥自身發生 Lua 錯誤時，會停止該指令碼繫結並清理。詞條移除、擁有者死亡、失去權威或任務結束後，未完成的回撥不能再追加效果；同步異常與無效載入結果也會被攔截。

## 支援的資源宣告

| `type` | 檔案 | 成功後使用的欄位 |
| --- | --- | --- |
| `texture` | `.png`、`.jpg`、`.jpeg`、`.dds`、已編譯 `.texture` | `texture`；普通圖片還可能返回寬高 |
| `font` | 已編譯 `.slug` 字型 | `font_type`，由管理器生成資源專屬別名 |
| `video` | `.ivf` 或 `.bk2` | 交給原生播放器的 `resource_name` |
| `mouse_cursor` | `.png`，另填 `hotspot_x`、`hotspot_y` | `resource_name` |
| `slug_album` | 已編譯 `.slug` 圖示冊 | `resource_name` |
| `material`、`particles`、`unit`、`animation` | 對應副檔名的已編譯資源 | `resource_name` |

這些型別對接作者的[資源介面](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/api/engine-resources.md)與[路徑／格式約定](https://github.com/deluxghost/darktide-mods/blob/main/SimpleAssets/docs/getting-started/paths.md)。引擎資源必須預先編譯到當前遊戲版本。所需 `.bones`、`.texture.stream` 等伴隨檔案也放在 `resources/` 中並列入 `files`，管理器會一起保留。已編譯檔案內嵌的路徑不會被改寫，引用的依賴不會自動載入。介面不轉換 FBX／Blender、TTF／OTF、MP4、MP3 或 WAV，也不因為支援影片就支援音軌與透明通道。全域性 `replace_*` 替換操作不屬於此作用域介面。

## 客戶端介面與 HUD

遊戲邏輯仍遵守房主權威規則。本地安裝的介面或 HUD 可以在客戶端單獨開啟資源作用域，無須建立遊戲邏輯引擎：

```lua
local manager = get_mod("MortisBuffManager") -- 或 HavocConditionManager
local scope, why = manager.diy_api.open_assets("my-entry-package")
if not scope then return end

-- 假設 image_widget 已有接受 texture_map 的圖片材質，
-- 且其可見性函式讀取 content.asset_ready。
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
-- 將 scope 儲存在介面中；銷燬介面前呼叫 scope:close("view_exit")。
```

`open_assets(package_id, active_predicate?)` 固定該作用域開啟時的本地配置庫快照。新開啟的作用域可以讀取重新整理後的資源；已有作用域與正在執行的遊戲邏輯仍保留舊版本。客戶端能開啟資源不代表該詞條已被選中，也不代表房主擁有相同檔案。`scope:load`、`scope:release`、`scope:own`、`scope:close` 使用相同的載入與清理規則。可選判定函式返回 false 後，管理器更新會關閉作用域。介面退出時仍應主動關閉，並在控制元件或渲染器銷燬前完成清理。

播放影片時，把 `resource_name` 交給 `UIRenderer.create_video_player`，並在 `scope:own` 登記 `UIRenderer.destroy_video_player`。單位、粒子例項也需要相應的原生銷燬函式；使用者還應負責恢復被自己更改的游標。釋放控制代碼不會自動銷燬由資源建立的世界物件、播放器或游標狀態。

## 快取與壽命

啟動及手動重新整理配置庫時，管理器在下列位置準備資源副本：

```text
%APPDATA%/Fatshark/Darktide/mods/<管理器名>/assets/diy-cache/<資源雜湊>/
```

原始包仍位於 `<管理器名>/diy/packages`。快取只含資源位元組，雜湊覆蓋排序後的資源路徑、內容、伴隨檔案及型別載入引數；只改游標熱點也會生成新原生標識，避免沿用舊熱點；只改 Lua 或包後設資料時可以複用相同資源目錄。已有副本會校驗，絕不覆蓋。請求資源時不會掃描、複製或重新計算包雜湊；SimpleAssets 會在首次載入時讀取／解碼資源。建議在詞條啟用或介面進入時請求，並保留控制代碼使用。

遊戲中修改原始檔不會替換本局副本；重新整理後的內容得到新目錄與原生標識。死靈的全房間指紋仍覆蓋清單、Lua、資源及依賴閉包，不透過網路傳送資源位元組、程式碼或使用者控制代碼。

每個管理器最多允許 256 個開啟的作用域、256 條成功或待完成的原生資源記錄；每個控制代碼最多有 16 個待執行回撥，每個作用域最多登記 64 個清理回撥。未完成請求在累計管理器更新時間達到 35 秒後失敗。磁碟快取最多 128 MiB、256 份資源快照，原來的包大小與單檔案限制仍適用。這些限制針對管理記錄與原始檔，並非視訊記憶體預算；解碼後的貼圖和引擎資源可能比原始檔大得多。

已檢查的載入器沒有通用的單資源解除安裝介面，因此成功的原生載入結果在程序內複用。關閉使用者會遮蔽回撥並執行登記的清理，不承諾釋放原生貼圖、字型等底層分配。影片可能持續讀取檔案，因此快取不會在任務結束時刪除。快取滿或內容被修改時，請先退出遊戲，僅刪除上述目錄中的本管理器 `assets/diy-cache`，再重新啟動；不要把源包目錄 `diy/packages` 當快取刪除。更換或重新載入 SimpleAssets 後應重啟遊戲。

## 驗證範圍

離線檢查覆蓋九種載入介面的引數、隔離環境中的真實 Windows Unicode 快取 IO、伴隨檔案、內容變化、快取篡改拒絕、磁碟／請求限制、併發複用、重試、超時、取消及回撥錯誤。實際死靈與 HCM 工廠還驗證了本局凍結、客戶端本地作用域和缺少依賴時的降級。原生載入邊界使用替身；實際遊戲顯示、編譯資源相容性與多人視覺效果仍需實機驗收。
