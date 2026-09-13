local Lifecycle = {}

function Lifecycle.is_current(parent, view_name)
    -- Both native and legacy shells set _child before constructing the page.
    -- The name remains assigned during loading, and is cleared on departure.
    return not parent or not parent.__deleted and not parent._workspace_closing
        and parent._child == view_name
end

function Lifecycle.attach(parent)
    if not parent or not parent._workspace_session_owned or parent._mbm_workspace_lifecycle then return end
    if type(parent._close_page) ~= "function" or type(parent.on_exit) ~= "function" then return end
    parent._mbm_workspace_lifecycle = true

    -- An older optional provider can own /rl. Guard that window instance so
    -- native teardown may destroy children before the parent's on_exit runs.
    local close_page, on_exit = parent._close_page, parent.on_exit
    parent._close_page = function(self, ...)
        if self._mbm_closing_page then return end
        if self._child and not Managers.ui:view_active(self._child) then
            local page = self._page
            if page and page.nodes_event and self._page_events[page.nodes_event] then
                self:_unregister_event(page.nodes_event)
                self._page_events[page.nodes_event] = nil
            end
            self._child, self._page = nil, nil
            return
        end
        self._mbm_closing_page = true
        close_page(self, ...)
        self._mbm_closing_page = nil
    end
    parent.on_exit = function(self, ...)
        self._workspace_closing, self._requested_page = true, nil
        return on_exit(self, ...)
    end
    local update, select_page = parent.update, parent.select_page
    if type(update) == "function" then
        parent.update = function(self, ...)
            if self._workspace_closing then return false, false end
            return update(self, ...)
        end
    end
    if type(select_page) == "function" then
        parent.select_page = function(self, ...)
            if self._workspace_closing then return false end
            return select_page(self, ...)
        end
    end
end

return Lifecycle
