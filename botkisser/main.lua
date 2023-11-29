local discordia = require('discordia')
local process = require('process').globalProcess()
local timer = require('timer')
local table = require('table')

local client = discordia.Client {
	cacheAllMembers = true,
	syncGuilds = true
}

local json = require("json")
local clock = discordia.Clock()

local bot_itself_id = '1169145779949154344'
local tem_id = '438590839384571905'
local prefix = '&'

-- Table to store server settings
local server_settings = {}

local function save_data(path, filename_no_extension, data)
	local f, err = io.open(path .. "/" .. filename_no_extension .. ".json", "w")
	if not f then
		os.execute("mkdir -p " .. path)
	end
	local f, err = io.open(path .. "/" .. filename_no_extension .. ".json", "w")
	if not f then
		return "no file"
	end

	local str = json.encode(data)
	if type(str) == 'string' then
		f:write(str)
		io.close(f)
	end

	return "ok"
end

local function load_data(path, filename_no_extension)
	local f, err = io.open(path .. "/" .. filename_no_extension .. ".json", "r")
	if not f then
		os.execute("mkdir -p " .. path)
	end
	local f, err = io.open(path .. "/" .. filename_no_extension .. ".json", "r")
	if not f then
		return "no file"
	end

	local data = json.decode(f:read("*a"))
	io.close(f)

	return data
end

local function clean_nils(t)
	for i = 1, #t do
		if t[i] == nil then
			table.remove(t, i)
		end
	end
	return t
end

local function set_system_command(command)
	local file = io.open("bot_command.txt", "wb")
	if file == nil then return end
	file:write(command)
	file:close()
end

local function exit_update()
	set_system_command("update")
	process:exit(0)
end

local function exit_stop()
	set_system_command("stop")
	process:exit(0)
end

local emoji_strs = {
	no = { "🇳", "🇴" },
	ok = { "🆗" },
	question = { "❓" }
}

local function react(message, emoji_str)
	for _, emoji in ipairs(emoji_str) do
		message:addReaction(emoji)
	end
	timer.setTimeout(3000, coroutine.wrap(message.clearReactions), message)
end

local function send_message_or_react(message, server_id, str, emoji_str)
	if server_settings[server_id].react or false then
		react(message, emoji_str)
	else
		message.channel:send(str)
	end
end

local function is_admin(message)
	if message.member.hasPermission then
		if not message.member:hasPermission("administrator") then
			return false
		end
	else
		print('sussy, no permissions at all......')
		return false
	end
	return true
end

local function has_admin_perms(message)
	if message.member.hasPermission == nil then
		print('no permissions method')
		return false
	end

	if message.member:hasPermission("administrator") then
		return true
	end
	-- The user does not have enough permissions
	send_message_or_react(message, message.guild.id,
		"You do not have `administrator` permissions, sorry!", emoji_strs.no)
	return false
end

local function update_setting(server_id, field_name, data)
	local settings = (server_settings[server_id] or {})
	settings[field_name] = data
	server_settings[server_id] = settings
	save_data("kisser_data", "server_settings", server_settings)
end

local function get_setting(server_id, field_name)
	return server_settings[server_id][field_name]
end
--
local function create_and_assign_role(server_id, user, name, color, exp_time)
	local guild = client:getGuild(server_id)
	local member = guild:getMember(user.id)

	local role = guild:createRole(name)

	role:setColor(color)
	member:addRole(role.id)

	local custom_roles = clean_nils(get_setting(server_id, "custom_roles")) or {}
	local role_entry = {}
	role_entry["user_id"] = user.id
	role_entry["role_id"] = role.id
	---@diagnostic disable-next-line: param-type-mismatch
	role_entry["exp_time"] = os.time(os.date('!*t')) + (exp_time * 60)

	table.insert(custom_roles, role_entry)

	update_setting(server_id, "custom_roles", custom_roles)
end

local function check_for_expired_roles(server_id)
	local guild = client:getGuild(server_id)
	local custom_roles = clean_nils(get_setting(server_id, "custom_roles")) or {}

	for i, v in ipairs(custom_roles) do
		---@diagnostic disable-next-line: param-type-mismatch
		if v["exp_time"] < os.time(os.date('!*t')) then
			if v == nil or v["role_id"] == nil then
				goto continue
			end
			local role = client:getRole(v["role_id"])
			custom_roles[i] = nil
			if role ~= nil then
				role:delete()
			end
		end
	    ::continue::
	end

	update_setting(server_id, "custom_roles", clean_nils(custom_roles))

	save_data("kisser_data", "server_settings", server_settings)
end

local function count_amount_of_custom_roles(server_id, user_id)
	local custom_roles = clean_nils(get_setting(server_id, "custom_roles")) or {}
	local count = 0

	for i, v in ipairs(custom_roles) do
		if v == nil then
			goto continue
		end
		if v["user_id"] == user_id then
			local role = client:getRole(v["role_id"])
			count = count + 1
		end
		::continue::
	end

	return count
end

-- template
-- admin only
-- { is_admin = 1 , name = "name", function = fname }
-- function template:
--[[
local function test(message,words,server_id)

end


local commands_table = {
	test_cmd = {
		admin_only = true,
		tem_only = true,
		name = "echo",
		args_desc = "( ... )",
		desc = "echoes anything you sent",
		fn = function(message, words, server_id)
			local str = message.content
			local str, i = str:gsub("1", "", 1)
			str = (i > 0) and str or str:gsub("^.-%s", "", 1)
			message.channel:send("There is what you just said:" .. str)
			return true
		end
	}
}
]]

local commands_table = {}

table.insert(commands_table, {
	name = "help",
	desc = "print commands that you can use",
	fn = function(message, words, server_id)
		local help_message = "Here is some of my commands for you, that you can use\n"

		for _, entry in ipairs(commands_table) do
			-- help prints only commands visible to user
			if (entry.admin_only and not is_admin(message)) or
				(entry.tem_only and message.author.id ~= tem_id) then
				goto continue
			end

			help_message = help_message
				.. '\t`'
				.. prefix
				.. (entry.name or "[no command name, must be bug]") .. "` "
				.. (entry.args_desc or "") .. " - "
				.. (entry.desc or "")
				.. "\n"
			::continue::
		end

		message.channel:send(help_message)
	end
})

table.insert(commands_table, {
	tem_only = true,
	name = "update",
	desc = "updates the bot from hitgub repos and then restarts.. for tem usage only!",
	fn = function(message, words, server_id)
		react(message, emoji_strs.ok)
		exit_update()
	end
})

table.insert(commands_table, {
	tem_only = true,
	name = "stop",
	desc = "stops the bot.. no restart though..",
	fn = function(message, words, server_id)
		react(message, emoji_strs.ok)
		exit_stop()
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = "set_channel",
	desc = "set the channel where i will kiss peopl",
	fn = function(message, words, server_id)
		update_setting(server_id, "kiss_channel_id", message.channel.id)
		send_message_or_react(message, server_id, 'Channel set as the kissing destination', emoji_strs.ok)
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = "set_period",
	args_desc = '(number)',
	desc = "set period in minutes",
	fn = function(message, words, server_id)
		if #words ~= 2 then
			send_message_or_react(message, server_id, "specify period in minutes, please...", emoji_strs
				.question)
			return
		end

		local num = tonumber(words[2]);

		if num ~= nil then
			update_setting(server_id, "kiss_every", num)
			send_message_or_react(message, server_id, 'Now i will kiss every ' .. num .. ' min', emoji_strs.ok)
		else
			send_message_or_react(message, server_id, 'Looks like not valid number....', emoji_strs.question)
		end
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'set_role',
	args_desc = '(pinged role / role id)',
	desc = 'set the role who will be kissed',
	fn = function(message, words, server_id)
		local mentioned_role_id
		if message.mentionedRoles.first ~= nil or words[2] ~= nil then
			mentioned_role_id = message.mentionedRoles.first.id
		else
			send_message_or_react(message, server_id, 'also specify role, please (ping them or give me role id)',
				emoji_strs.question)
		end

		update_setting(server_id, "role_kiss_id", mentioned_role_id)

		send_message_or_react(message, server_id, 'Set ' .. message.mentionedRoles.first.name
			.. '( id:' .. mentioned_role_id .. ') as role to kiss', emoji_strs.ok)
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'set_role_exp_time',
	args_desc = '(time in minutes)',
	desc = 'how long it takes for custom roles to dissolve in air',
	fn = function(message, words, server_id)
		if #words ~= 2 then
			send_message_or_react(message, server_id, "specify period in minutes, please...", emoji_strs
				.question)
			return
		end

		local num = tonumber(words[2]);

		if num ~= nil then
			update_setting(server_id, "role_exp_time", num)
			send_message_or_react(message, server_id, 'now roles will dissolve in ' .. num .. ' min', emoji_strs.ok)
		else
			send_message_or_react(message, server_id, 'Looks like not valid number....', emoji_strs.question)
		end
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'get_settings',
	desc = 'dump setings to chat in json format',
	fn = function(message, words, server_id)
		message.channel:send(json.encode(server_settings[server_id]))
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'set_settings',
	args_desc = '(json string)',
	desc = 'apply settings from json string',
	fn = function(message, words, server_id)
		local content = message.content:gsub("^.-%s", "", 1)
		server_settings[server_id] = json.decode(content)

		save_data("kisser_data", "server_settings", server_settings)
		send_message_or_react(message, server_id, 'Done!.. i think..', emoji_strs.ok)
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'toggle',
	args_desc = '[feature name]',
	desc = 'togles off or on some bot features\n'
		.. '\t\t`custom_role` - \"role dispenser\" feature\n'
		.. '\t\t`react` - when on, reacts on commands with temporary emojis (when possible)',
	fn = function(message, words, server_id)
		if words[2] == nil then
			send_message_or_react(message, server_id, 'choose feature name to toggle..', emoji_strs.question)
		end

		local toggle_state = (not get_setting(server_id, "toggle_" .. words[2]) or false)
		update_setting(server_id, "toggle_" .. words[2], toggle_state)

		send_message_or_react(message, server_id,
			'Done!.. i think.. ' .. 'now its ' .. (toggle_state and "true" or "false"), emoji_strs.ok)
	end
})

table.insert(commands_table, {
	name = "give_me_role",
	args_desc = "(role name) (color hex code, example: #5588af)",
	desc = "sets custom role for you! will expire after some time..",
	fn = function(message, words, server_id)
		if not (get_setting(server_id, "toggle_custom_role") or false) then
			send_message_or_react(message, server_id,
				'feature is disbled rn.. sowwy', emoji_strs.no)
			return
		end

		local limit = get_setting(server_id, "role_limit") or 0
		if limit == 0 then
			send_message_or_react(message, server_id,
				'role limit is not set yet..', emoji_strs.question)
			return
		end

		local roles_count = count_amount_of_custom_roles(server_id, message.author.id)
		if roles_count >= limit then
			send_message_or_react(message, server_id,
				'oonono, too many roles for you, my friend!.. limit is ' .. limit .. ' btw', emoji_strs.no)
			message.channel:send('https://tenor.com/view/powerful-head-slap-anime-death-tragic-gif-14358509')
			return
		end

		if #words ~= 3 then
			send_message_or_react(message, server_id,
				'wrong argument number: only role name and color hex code required..', emoji_strs.question)
			return
		end

		local exp_time = get_setting(server_id, "role_exp_time")
		if not exp_time then
			send_message_or_react(message, server_id, 'sorry, expiration time is not set on this server yet...',
				emoji_strs.question)
			return
		end

		create_and_assign_role(server_id,
			message.author,
			words[2],
			discordia.Color.fromHex(words[3]),
			exp_time)
		send_message_or_react(message, server_id, 'Enjoy your new shiny role! it will expire after ' ..
			exp_time .. ' min and you have ' .. limit - roles_count .. ' more role slots', emoji_strs.ok)
	end
})

table.insert(commands_table, {
	admin_only = true,
	name = 'set_role_limit',
	args_desc = '(number)',
	desc = 'how many custom roles i can create for a person',
	fn = function(message, words, server_id)
		if #words ~= 2 then
			send_message_or_react(message, server_id, "specify a number, pleasb...", emoji_strs.question)
			return
		end

		local num = tonumber(words[2]);

		if num ~= nil then
			update_setting(server_id, "role_limit", num)
			send_message_or_react(message, server_id, 'now single person can create maximum ' .. num .. ' custom roles',
				emoji_strs.ok)
		else
			send_message_or_react(message, server_id, 'its not a number....', emoji_strs.question)
		end
	end
})

local function command_handle(message, words, server_id)
	local command = nil
	for _, entry in ipairs(commands_table) do
		if words[1] == prefix .. entry.name then
			if ((entry.tem_only or false) and message.author.id ~= tem_id) then
				send_message_or_react(message, server_id, 'its for tem only!..', emoji_strs.no)
				return
			end
			if ((entry.admin_only or false) and not has_admin_perms(message)) then
				print(entry.admin_only, has_admin_perms(message))
				send_message_or_react(message, server_id, 'its for admins only!..', emoji_strs.no)
				return
			end
			command = entry
			break
		end
		::continue::
	end

	if command == nil then
		react(message, emoji_strs.question)
		return
	end

	command.fn(message, words, server_id)
end

client:on('messageCreate', function(message)
	-- do not react at my own messages
	if message.author.id == bot_itself_id then return end
	-- ignore bot messages
	if message.author.bot then return end

	print('[KISSINFO] author: ' .. message.author.username ..
		' content: ' .. message.content ..
		' channel type: ' .. message.channel.type)

	-- check if its even a command or not
	if string.sub(message.content, 1, 1) ~= prefix then
		return
	end

	local words = {}
	for word in message.content:gmatch("%S+") do table.insert(words, word) end

	local server_id = message.guild.id or false

	if not server_id then
		print('no server_id')
		return
	end

	if server_settings[server_id] == nil then
		print('[WARNING] no settings for server ' .. server_id)
	end

	command_handle(message, words, server_id)
end)

clock:on("min", function()
	for guild in client.guilds:iter() do
		local server_id = guild.id

		check_for_expired_roles(server_id)

		local personal_counter
		local kiss_every

		if server_settings[server_id] == nil then
			print('no settings for server ' .. server_id)
			goto continue
		end

		personal_counter = server_settings[server_id].counter or 0
		kiss_every = server_settings[server_id].kiss_every or 0

		server_settings[server_id].counter = personal_counter + 1

		if personal_counter % kiss_every ~= 0 then
			goto continue
		end

		print('kissing in ' .. server_id)
		-- Find the corresponding channel for the current guild
		local kiss_channel_id = server_settings[server_id].kiss_channel_id
		if not kiss_channel_id then
			print("channel is not set for guild " .. server_id .. ", not kissind at all")
			goto continue
		end

		-- set required role, or default role if not set for this server
		local required_role_id = server_settings[server_id].role_kiss_id
		if required_role_id == nil then
			print("role is not set for guild " .. server_id .. ", falling at default role")
			required_role_id = guild.defaultRole.id
		end

		-- choose member
		local random_person = guild.members:random()
		while random_person.user.id == bot_itself_id -- dont kiss yourself
			or random_person.user.bot == true  --dont kiss bots
			or random_person.roles:find(function(o) -- dont kiss people who doesnt have kiss role
				return o.id == required_role_id
			end) == nil
		do
			random_person = guild.members:random()
		end

		local channel = guild:getChannel(kiss_channel_id)
		channel:send(random_person.mentionString .. ', you have been kissed!')

		save_data("kisser_data", "server_settings", server_settings)
		::continue::
	end
end)

client:on('ready', function()
	-- client.user is the path for your bot
	print('Logged in as ' .. client.user.username)
	print('bot owner id: ' .. client.owner.id)

	local ret = load_data("kisser_data", "server_settings")
	if type(ret) == "table" then
		server_settings = ret
		print('Successful server settings load:')
		print(json.encode(server_settings))
	else
		print('No server settings found, sad')
		exit_stop()
	end
end)

client:enableAllIntents()

clock:start()

local tokenfile = io.open("token.txt", "rb")

if tokenfile == nil then
	print("no token file")
	return
end

-- to prevent infinite git pulls or something
set_system_command("error")

client:run('Bot ' .. tokenfile:read())
