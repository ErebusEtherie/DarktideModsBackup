-- Shared rendering constants for Improve Yourself UI surfaces.
--
-- IMPORTANT: These values are part of the proven 0.13.9 rendering baseline.
-- Keep the mission-end root, visual passes, content, and render pass separated;
-- lowering only one of them can allow Darktide reward widgets to split the board.
return {
    render_layer = 3000,

    victory = {
        width = 1060,
        height = 725,
        root_z = 100,
        visual_z = 200,
        content_z = 222,
        reward_phase_y_offset = -50,
    },

    tactical = {
        base_z = 800,
    },
}
