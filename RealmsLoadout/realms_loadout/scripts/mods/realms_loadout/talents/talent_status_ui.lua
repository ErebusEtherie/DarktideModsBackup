-- Uses the talent view's existing canvas and font. No texture packages to load.
local Status = {}
Status.geometry = { x = 12, y = 240, width = 378, height = 78, row = 18, font = 16 }

function Status.definition(UIWidget)
	local g = Status.geometry
	local passes = { { pass_type = "rect", style_id = "background", style = {
		color = { 215, 12, 20, 16 }, size = { g.width, g.height }, offset = { g.x, g.y, 25 },
		horizontal_alignment = "left", vertical_alignment = "top" } } }
	for i = 1, 4 do
		passes[#passes + 1] = { pass_type = "text", value = "", value_id = "line" .. i, style_id = "line" .. i,
			style = { font_type = "proxima_nova_bold", font_size = g.font,
				text_color = i == 1 and { 255, 221, 194, 122 } or { 255, 205, 216, 202 },
				horizontal_alignment = "left", vertical_alignment = "top",
				text_horizontal_alignment = "left", text_vertical_alignment = "center",
				size = { g.width - 16, g.row }, offset = { g.x + 8, g.y + 3 + (i - 1) * g.row, 26 } } }
	end
	return UIWidget.create_definition(passes, "info_banner", { visible = false })
end

function Status.lines(model, tr)
	local role = model.role or "local"
	local status = model.status or role
	if role == "host" then
		status = model.total == 0 and "empty" or "members"
		if (model.incompatible or 0) > 0 then status = "mismatch" end
	elseif role == "client" and model.draft and model.enabled then
		status = "draft"
	end
	return {
		tr("tpm_status_heading", tr("tpm_role_" .. role), model.spent, model.cap),
		tr("tpm_status_choices", tr(model.auras and "tpm_multi" or "tpm_single"), tr(model.keystones and "tpm_multi" or "tpm_single")),
		status == "members" and tr("tpm_status_members", model.confirmed, model.total) or tr("tpm_status_" .. status),
		role == "host" and tr("tpm_status_guest_budget", model.guest_cap)
			or role == "client" and tr(model.has_rules and "tpm_status_host_scope" or "tpm_status_native_scope")
			or tr("tpm_status_local_scope"),
	}
end

return Status
