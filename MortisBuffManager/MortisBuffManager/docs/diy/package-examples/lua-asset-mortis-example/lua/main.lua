-- Optional resource probe. See ASSETS.en.md / ASSETS.zh-CN.md.
return {api_version={major=1,minor=1},entries={asset_probe={
    on_activate=function(ctx)
        local handle,why=ctx:load_asset("badge",function(asset,load_error)
            if asset then
                ctx.state.texture=asset.texture
                ctx:log("Test texture ready (16 x 16).")
            else ctx:log(load_error) end
        end)
        if not handle then ctx:log(why) end
    end
}}}
