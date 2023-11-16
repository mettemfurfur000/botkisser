local discordia = require('discordia')
local process = require('process').globalProcess()

local client = discordia.Client {
	cacheAllMembers = true,
	syncGuilds = true
}

local json = require("json")
local clock = discordia.Clock()

local bot_itself_id = '1169145779949154344'
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

local function dump(o)
	if type(o) == 'table' then
		local s = '{ '
		for k, v in pairs(o) do
			if type(k) ~= 'number' then k = '"' .. k .. '"' end
			s = s .. '[' .. k .. '] = ' .. dump(v) .. ','
		end
		return s .. '} '
	else
		return tostring(o)
	end
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

client:on('messageCreate', function(message)
	-- do not react at my own messages
	if message.author.id == bot_itself_id then return end

	print('[KISSINFO] author: ' .. message.author.username ..
		' content: ' .. message.content ..
		' channel type: ' .. message.channel.type)

	if message.author.hasPermission then
		if not message.author:hasPermission("administrator") then
			-- The user does not have enough permissions
			message:reply("You do not have `administrator` permissions!")
			return
		end
	end

	local words = {}
	for word in message.content:gmatch("%S+") do table.insert(words, word) end

	local server_id = message.guild.id
	local channel_id = message.channel.id
	local role_id
	if message.mentionedRoles.first then
		role_id = message.mentionedRoles.first.id
	end

	local settings
	if server_settings[server_id] ~= nil then
		settings = server_settings[server_id]
	else
		settings = {}
	end

	if server_id == nil then
		print('no server_id')
		return
	end
	if channel_id == nil then
		print('no channel_id')
		return
	end
	if server_id == nil then
		print('no server_id')
		return
	end

	if words[1] == prefix .. 'help' then
		message.channel:send('There is my comamnd if yu want to know!! \n'
			.. prefix .. 'set_channel - set channel where i will kiss peopl\n'
			.. prefix .. 'set_role - set role who wil be kissed\n'
			.. prefix .. 'set_period - set period in minutes\n')
	end

	if words[1] == prefix .. 'set_channel' then
		settings["kiss_channel_id"] = channel_id
		message.channel:send('Channel set as the kissing destination')
	end

	if words[1] == prefix .. 'set_role' then
		settings["role_kiss_id"] = role_id
		message.channel:send('Set ' .. message.mentionedRoles.first.name .. '(' .. role_id .. ') as role to kiss')
	end

	if words[1] == prefix .. 'set_period' then
		local num = tonumber(words[2]);
		if num ~= nil then
			message.channel:send('Now i will kiss every ' .. num .. ' min')
		else
			num = 360
			message.channel:send('Looks like not valid number, falling to default value of 6 hrs (360 mins)..')
		end
		settings["kiss_every"] = num
	end

	server_settings[server_id] = settings

	save_data("kisser_data", "server_settings", server_settings)
end)

clock:on("min", function()
	exit_stop()
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

		server_settings[server_id].counter = personal_counter + 1

		if personal_counter % kiss_every ~= 0 then
			goto continue
		end

		-- for now ignore other servers
		-- if server_id ~= "796805731890364447" then
		-- 	print("ignoring this one")
		-- 	goto continue
		-- end

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
		-- roll again to find not bot and members with required role
		-- every condition must be false to stop randompicking
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
		-- if random_person.nickname ~= nil then
		-- 	channel:send(random_person.nickname .. ', you have been kissed!')
		-- else
		-- 	channel:send(random_person.user.name .. ', you have been kissed!')
		-- end

		save_data("kisser_data", "server_settings", server_settings)
		::continue::
	end
end)

client:on('ready', function()
	-- client.user is the path for your bot
	print('Logged in as ' .. client.user.username)
	
	local ret = load_data("kisser_data", "server_settings")
	if type(ret) == "table" then
		server_settings = ret
		print('Successful server settings load:')
		print(dump(server_settings))
	end
end)

client:enableAllIntents()

clock:start()

local tokenfile = io.open("token.txt", "rb")

if tokenfile == nil then print("no token file") return end

client:run('Bot '..tokenfile:read())
