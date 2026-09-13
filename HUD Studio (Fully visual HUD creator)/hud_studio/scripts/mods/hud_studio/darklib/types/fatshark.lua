---@meta types

---@alias FS_DamageEfficiency "full" | "reduced" | "negated" | "push"

---@class FS_DamageProfile
---@field name string
---@field melee_attack_strength string | nil  # e.g. "light" | "heavy" (melee_attack_strengths)
---@field charge_level_scaler any | nil
---@field targets table | nil

---@alias FS_HookCallback_AttackReportManager_AddAttackResult fun(

