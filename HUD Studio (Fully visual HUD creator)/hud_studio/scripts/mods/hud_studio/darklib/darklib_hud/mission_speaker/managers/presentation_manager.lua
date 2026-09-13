
---@param module DLH_MissionSpeaker
return function(module)
	if module.presentation_manager then
		return module.presentation_manager
	end

	---@class DLH_MissionSpeakerPresentationManager
	local PresentationManager = {}

	function PresentationManager.text_offset_x()
		return -(module.constants.PRESENTATION.PORTRAIT_SIZE[1] + module.constants.PRESENTATION.TEXT_GAP)
	end

	function PresentationManager.bar_offset_x(i)
		return module.constants.PRESENTATION.BAR_OFFSET[1]
			- (module.constants.PRESENTATION.BAR_SIZE[1] + module.constants.PRESENTATION.BAR_SPACING) * (i - 1)
	end

	function PresentationManager.alignment_side()
		return module.state.align_side or "right"
	end

	function PresentationManager.offset_y()
		return module.state.offset_y or 0
	end

	module.presentation_manager = PresentationManager
end
