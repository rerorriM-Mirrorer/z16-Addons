-- Contributor: Codex (per-door attempt limit and explanatory comments)
_addon.name = 'OpenSesame'
_addon.author = 'Arcon'
_addon.version = '1.1.0.0'
_addon.language = 'english'
_addon.commands = {'opensesame', 'os'}

require('luau')
packets = require('packets')

defaults = {}
defaults.Auto = false
defaults.Range = 10
defaults.MaxAttempts = 4

settings = config.load(defaults)

-- The nearby-door list is rebuilt often. Keep cooldowns and visit counts separately
-- so rescanning the list cannot silently allow another attempt on a paused door.
last = {}
attempts = {}
doors = S{}

local RESET_MARGIN = 3
local RESET_DELAY = 2

update_doors = function()
    if not settings.Auto then
        return
    end

    local mobs = windower.ffxi.get_mob_array()
    doors:clear()
    for index, mob in pairs(mobs) do
        if mob.spawn_type == 34 and mob.distance < 2500 then
            doors:add(index)
        end
    end
end

update_doors()

exceptions = S{
    17097337,
}

-- A door's name may be shared by other doors, and its array index is local to
-- the zone. Its full ID identifies which door's attempts we should count.
check_door = function(door)
    return door
        and door.spawn_type == 34
        and door.distance < settings.Range^2
        and (not last[door.id] or os.time() - last[door.id] > 7)
        and (not attempts[door.id] or attempts[door.id].count < settings.MaxAttempts)
        and door.name:byte() ~= 95
        and door.name ~= 'Furniture'
        and not exceptions:contains(door.id)
end

-- A short step past the opening range should not restart the count. Once the
-- player has stayed farther away for two seconds, that door is ready again.
-- Saved coordinates still work if the door has left the client's mob array.
reset_distant_doors = function()
    local player = windower.ffxi.get_mob_by_target('me')
    if not player then
        return
    end

    local now = os.time()
    local reset_range_squared = (settings.Range + RESET_MARGIN)^2
    for id, visit in pairs(attempts) do
        local door = windower.ffxi.get_mob_by_id(id)
        local distance_squared
        if door then
            distance_squared = door.distance
        else
            local dx = player.x - visit.x
            local dy = player.y - visit.y
            local dz = player.z - visit.z
            distance_squared = dx^2 + dy^2 + dz^2
        end

        if distance_squared > reset_range_squared then
            visit.outside_since = visit.outside_since or now
            if now - visit.outside_since >= RESET_DELAY then
                attempts[id] = nil
            end
        else
            visit.outside_since = nil
        end
    end
end

frame_count = 0
windower.register_event('prerender', function()
    if not windower.ffxi.get_info().logged_in then
        frame_count = 0
        return
    end

    frame_count = frame_count + 1
    if frame_count == 30 then
        update_doors()
        reset_distant_doors()
        frame_count = 0
    end

    local open = T{}
    if settings.Auto then
        for index in doors:it() do
            local door = windower.ffxi.get_mob_by_index(index)
            if check_door(door) then
                open[door.index] = door.id
            end
        end
    else
        -- Auto off still opens a targeted door; use the same limit here so an
        -- idle character cannot resume the loop merely by targeting that door.
        local door = windower.ffxi.get_mob_by_target()
        if door and check_door(door) then
            open[door.index] = door.id
        end
    end

    for id, index in open:it() do
        -- A door can leave memory between the scan and this loop. In that case,
        -- skip the request and avoid counting an attempt that was never sent.
        local door = windower.ffxi.get_mob_by_id(id)
        if door and door.index == index then
            packets.inject(packets.new('outgoing', 0x01A, {
                ['Target'] = id,
                ['Target Index'] = index
            }))
            last[id] = os.time()

            -- Count requests this addon sends. A request alone does not prove
            -- the game opened the door; this also stops failed repeats.
            local visit = attempts[id] or {count = 0}
            visit.count = visit.count + 1
            visit.x, visit.y, visit.z = door.x, door.y, door.z
            visit.outside_since = nil
            attempts[id] = visit
            if visit.count == settings.MaxAttempts then
                log(('Paused %s (ID %d) after %d attempts. Move away or use //os reset.')
                    :format(door.name, id, visit.count))
            end
        end
    end
end)

-- Door IDs belong to a zone. A fresh visit after zoning or logging in starts
-- with fresh counts; the configured limit itself remains saved.
windower.register_event('logout', 'zone change', function()
    last = {}
    attempts = {}
    doors:clear()
end)

windower.register_event('addon command', function(command, ...)
    command = command and command:lower()
    local args = {...}

    if command == 'auto' then
        if args[1] == 'on' then
            settings.Auto = true
        elseif args[1] == 'off' then
            settings.Auto = false
        else
            settings.Auto = not settings.Auto
        end

        update_doors()

        log(('Automatic door opening %s.'):format(settings.Auto and 'enabled' or 'disabled'))
        config.save(settings)

    elseif command == 'limit' then
        if not args[1] then
            log(('Door attempt limit: %d.'):format(settings.MaxAttempts))
            return
        end

        local limit = tonumber(args[1])
        if not limit or limit % 1 ~= 0 or limit < 1 or limit > 20 then
            log('Use //os limit <1-20>.')
            return
        end

        -- Keep the current counts: raising the limit permits further attempts,
        -- while lowering it pauses doors that have already reached the new cap.
        settings.MaxAttempts = limit
        config.save(settings)
        log(('Door attempt limit set to %d.'):format(limit))

    elseif command == 'reset' then
        -- Reset the visit counts, but retain the seven-second cooldown.
        attempts = {}
        log('Door attempt counts reset.')

    else
        print(_addon.name .. ' v' .. _addon.version .. ':')
        print('  auto [on|off] - Sets automatic door opening to on/off or toggles it')
        print('  limit [1-20] - Shows or sets the number of attempts allowed per door')
        print('  reset - Clears door attempt counts for the current zone')

    end
end)
