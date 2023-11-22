local discordia = require('discordia')
local process = require('process').globalProcess()

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

local function is_admin(message)
	if message.member.hasPermission then
		if not message.member:hasPermission("administrator") then
			-- The user does not have enough permissions
			message:reply("You do not have `administrator` permissions, sorry!")
			return false
		end
	else
		print('sussy, no permissions at all......')
		return false
	end
	return true
end

local function update_setting(server_id, field_name, data)
	local settings
	if server_settings[server_id] ~= nil then
		settings = server_settings[server_id]
	else
		settings = {}
	end

	settings[field_name] = data

	server_settings[server_id] = settings

	save_data("kisser_data", "server_settings", server_settings)
end

local function handle_tem(message, words)
	if words[1] == 'help' then
		message.channel:send('ar u mad? look there is my comadns:\n'
			.. 'help - this message\n'
			.. 'update - update from github\n'
			.. 'stop - stop bot forever\n')
	end

	if words[1] == 'update' then
		exit_update()
	end

	if words[1] == 'stop' then
		exit_stop()
	end
end

local function handle_command(message, words)
	local server_id = message.guild.id

	if server_id == nil then
		print('no server_id')
		return
	end

	if words[1] == prefix .. 'help' then
		message.channel:send('There is my comamnd if yu want to know!! \n'
			.. prefix .. 'set_channel - set channel where i will kiss peopl\n'
			.. prefix .. 'set_role (role ping / role id) - set role who will be kissed\n'
			.. prefix .. 'set_period (number) - set period in minutes\n'
			.. prefix .. 'get_settings - dump setings to chat in json format\n'
			.. prefix .. 'set_settings {json string} - apply settings from json string\n'
			.. prefix .. 'help - show this mesage')
		return
	end

	if words[1] == prefix .. 'set_channel' and is_admin(message) then
		update_setting(server_id, "kiss_channel_id", message.channel.id)
		message.channel:send('Channel set as the kissing destination')
		return
	end

	if words[1] == prefix .. 'set_role' and is_admin(message) then
		local mentioned_role_id
		if message.mentionedRoles.first ~= nil or words[2] ~= nil then
			mentioned_role_id = message.mentionedRoles.first.id
		else
			message.channel:send('Also specify role, please (ping them or give me role id)')
		end

		update_setting(server_id, "role_kiss_id", mentioned_role_id)
		message.channel:send('Set ' ..
			message.mentionedRoles.first.name .. '( id:' .. mentioned_role_id .. ') as role to kiss')
		return
	end

	if words[1] == prefix .. 'set_period' and is_admin(message) then
		local num = tonumber(words[2]);
		if num ~= nil then
			update_setting(server_id, "kiss_every", num)
			message.channel:send('Now i will kiss every ' .. num .. ' min')
		else
			message.channel:send('Looks like not valid number....')
		end
		return
	end

	if words[1] == prefix .. 'get_settings' and is_admin(message) then
		message.channel:send(json.encode(server_settings[server_id]))
		return
	end

	if words[1] == prefix .. 'set_settings' and is_admin(message) then
		local content = message.content:gsub("^.-%s", "",1) 
		server_settings[server_id] = json.decode(content)

		save_data("kisser_data", "server_settings", server_settings)
		message.channel:send('Done!.. i think..')
	end
end

client:on('messageCreate', function(message)
	-- do not react at my own messages
	if message.author.id == bot_itself_id then return end

	print('[KISSINFO] author: ' .. message.author.username ..
		' content: ' .. message.content ..
		' channel type: ' .. message.channel.type)

	local words = {}
	for word in message.content:gmatch("%S+") do table.insert(words, word) end

	if message.author.id == tem_id and message.channel.type == discordia.enums.channelType.private then
		handle_tem(message, words)
		return
	end

	handle_command(message, words)
end)

clock:on("min", function()
	for guild in client.guilds:iter() do
		local server_id = guild.id

		local personal_counter
		local kiss_every

		if server_settings[server_id] == nil then
			print('no settings for server ' .. server_id)
			goto continue
		end

		personal_counter = server_settings[server_id].counter or 0
		kiss_every = server_settings[server_id].kiss_every or 0

		if personal_counter % kiss_every ~= 0 then
			server_settings[server_id].counter = personal_counter + 1
			goto continue
		end

		personal_counter = 0

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
