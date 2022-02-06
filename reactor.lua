local component = require("component")
local term = require("term")
local computer = require("computer")
local unicode = require("unicode")
local gpu = component.gpu
local screen = component.screen

if component.isAvailable("br_reactor") then
	reactor = component.br_reactor
else
	print("Reactor is not connected. Please connect computer to reactor computer port")
	os.exit()
end

if component.isAvailable("me_controller") then
	me_controller = component.me_controller
end

if component.isAvailable("energy_device") then
	eio_capacitor = component.energy_device
end



local display_Settings = {
	reactor_Control = true, -- Allow reactor control. If false, the program will work only as a monitor, not a controller.
	reactor_Storage_Mode = false, -- Reactor storage mode. In this mode, the program will always keep the reactor OFF.
	ME_Storage_Support = false, -- Support for external storage (Calculation of the remaining operating time with the fuel in the storage, and displaying the fuel in the storage on the screen).
	EIO_Capacitor_Support = false, -- EnderIO support (Displaying EnderIO capacitor capacity).
	reactor_Percent_Off = 100, -- Percentage of filling of the reactor battery at which it will automatically turn off.
	reactor_Percent_Hysteresis = 20, -- Reactor battery filling hysteresis. For example, at 20, the reactor will start when battery 80%.
	reactor_Name = "Nexus-6", -- Reactor name.
}



local ME_Filter = {
	name = "bigreactors:ingotyellorium" -- ID слитка йеллоурита
}

local raw_Data = {
	reactor_Active = false,
	reactor_Available = false,
	reactor_State = "storage_Mode",
	reactor_Casing_Temp = 0,
	reactor_Fuel_Info = {
		fuelAmount = 0,
		fuelCapacity = 0,
		fuelConsumedLastTick = 0,
		fuelReactivity = 0,
		fuelTemperature = 0,
		wasteAmount = 0,
	},
	reactor_Energy_Info = {
		energyCapacity = 0,
		energyProducedLastTick = 0,
		energyStored = 0,
	},
	display_Resolution = {
		x = 0,
		y = 0,
	},
	ME_Data = {},
	ME_Yellorium_Amount = 0,
	EIO_Capacity_Max = 0,
	EIO_Capacity_Current = 0,
}

local calculated_Data = {
	reactor_Casing_Temp = 0,
	fuel_Temp = 0,
	fuel_Consume = 0,
	ME_Fuel_Store = 0,
	ME_Support_String = "",
	EIO_Charge_Percent = 0,
	EIO_Charge_Capacity = 0,
	total_Reactor_Fuel = 0,
	reactor_Fuel_Percent = 0,
	waste_Percent = 0,
	out_Of_Fuel = 0,
	time_Suffix = " min",
	energy_Stored = 0,
	energy_Generation = 0,
	energy_Suffix = " kRF/t",
	energy_Percent = 0,
	last_On_Sec = 0,
	last_On_Time = 0,
	last_On_Suffix = " sec ago",
}



function support_Check()
	if display_Settings["ME_Storage_Support"] and not me_controller then
		print("ME Controller is not connected. ME Support turned Off.")
		display_Settings["ME_Storage_Support"] = false
		os.sleep(3)
	end
	
	if display_Settings["EIO_Capacitor_Support"] and not eio_capacitor then
		print("EnderIO capacitor is not connected. EnderIO Support turned Off.")
		display_Settings["EIO_Capacitor_Support"] = false
		os.sleep(3)
	end
	
	if display_Settings["reactor_Storage_Mode"] then
		display_Settings["reactor_Control"] = true
	end
end



function time_Calculation()
	if raw_Data["reactor_Active"] then
		calculated_Data["last_On_Sec"] = 0
		calculated_Data["last_On_Suffix"] = " "
		calculated_Data["last_On_Time"] = "Now"
	else
		calculated_Data["last_On_Sec"] = calculated_Data["last_On_Sec"] + 1
		
		if calculated_Data["last_On_Sec"] < 60 then
			calculated_Data["last_On_Suffix"] = " sec ago"
			calculated_Data["last_On_Time"] = calculated_Data["last_On_Sec"]
		elseif calculated_Data["last_On_Sec"] > 86400 then
			calculated_Data["last_On_Suffix"] = " days ago"
			calculated_Data["last_On_Time"] = math.floor(calculated_Data["last_On_Sec"] / 86400)
		elseif calculated_Data["last_On_Sec"] > 3600 then
			calculated_Data["last_On_Suffix"] = " hours ago"
			calculated_Data["last_On_Time"] = math.floor(calculated_Data["last_On_Sec"] / 3600)
		elseif calculated_Data["last_On_Sec"] >= 60 then
			calculated_Data["last_On_Suffix"] = " min ago"
			calculated_Data["last_On_Time"] = math.floor(calculated_Data["last_On_Sec"] / 60)
		end
	end
end



function reactor_Control()
	if display_Settings["reactor_Storage_Mode"] then
		raw_Data["reactor_State"] = "Storage"
		reactor.setActive(false)
	else
		
		if raw_Data["reactor_Fuel_Info"]["fuelAmount"] > 0 then
			if display_Settings["reactor_Control"] then
				if calculated_Data["energy_Percent"] >= display_Settings["reactor_Percent_Off"] then
					reactor.setActive(false)
				elseif calculated_Data["energy_Percent"] <= display_Settings["reactor_Percent_Off"] - display_Settings["reactor_Percent_Hysteresis"] then
					reactor.setActive(true)
				end
			end
		else
			reactor.setActive(false)
		end
			
		if raw_Data["reactor_Active"] then
			raw_Data["reactor_State"] = "on"
		else
			raw_Data["reactor_State"] = "off"
		end
		
		if raw_Data["reactor_Fuel_Info"]["fuelAmount"] == 0 then
			raw_Data["reactor_State"] = "out_Of_Fuel"
		end
	end
end



function reactor_Availability_Changed()
	if not raw_Data["reactor_Available"] then
		term.clear()
		gpu.setForeground(0xffffff)
		gpu.setResolution(24, 8)

		local reactor_Name_Position = math.floor((24 - unicode.len(display_Settings["reactor_Name"])) / 2) + 1
		gpu.set(reactor_Name_Position, 2, display_Settings["reactor_Name"])
		gpu.set(4, 5, "Lost communication")
		gpu.set(7, 6, "with reactor")

		computer.beep(1000, 1)

	else
		gpu.setResolution(raw_Data["display_Resolution"]["x"], raw_Data["display_Resolution"]["y"])
	end
end



function data_Collector()
	if not raw_Data["reactor_Available"] == component.isAvailable("br_reactor") then
		raw_Data["reactor_Available"] = component.isAvailable("br_reactor")
		reactor_Availability_Changed()
	end

	if component.isAvailable("br_reactor") and raw_Data["reactor_Available"] then
		raw_Data["reactor_Active"] = reactor.getActive()
		raw_Data["reactor_Casing_Temp"] = reactor.getCasingTemperature()
		raw_Data["reactor_Fuel_Info"] = reactor.getFuelStats()
		raw_Data["reactor_Energy_Info"] = reactor.getEnergyStats()
		
		reactor_Control()
		data_Calculation()
	else
		time_Calculation()
	end
	
	if component.isAvailable("me_controller") and display_Settings["ME_Storage_Support"] then
		raw_Data["ME_Data"] = me_controller.getItemsInNetwork(ME_Filter)
		
		if raw_Data["ME_Data"][1] then
			raw_Data["ME_Yellorium_Amount"] = raw_Data["ME_Data"][1]["size"]
		else
			raw_Data["ME_Yellorium_Amount"] = 0
		end
	end
	
	if component.isAvailable("energy_device") and display_Settings["EIO_Capacitor_Support"] then
		raw_Data["EIO_Capacity_Current"] = eio_capacitor.getEnergyStored()
		raw_Data["EIO_Capacity_Max"] = eio_capacitor.getMaxEnergyStored()
	end
end



function data_Calculation()
	calculated_Data["reactor_Casing_Temp"] = math.floor(raw_Data["reactor_Casing_Temp"])
	calculated_Data["fuel_Temp"] = math.floor(raw_Data["reactor_Fuel_Info"]["fuelTemperature"])
	calculated_Data["fuel_Consume"] = math.floor((((raw_Data["reactor_Fuel_Info"]["fuelConsumedLastTick"] * 25) * 60) / 1000) * 100) / 100
	calculated_Data["energy_Stored"] = math.floor(raw_Data["reactor_Energy_Info"]["energyStored"] / 1000)
	calculated_Data["energy_Generation"] = raw_Data["reactor_Energy_Info"]["energyProducedLastTick"]
	calculated_Data["energy_Percent"] = math.floor((raw_Data["reactor_Energy_Info"]["energyStored"] / raw_Data["reactor_Energy_Info"]["energyCapacity"]) * 100)
	calculated_Data["EIO_Charge_Capacity"] = math.floor(raw_Data["EIO_Capacity_Current"] / 1000)
	calculated_Data["EIO_Charge_Percent"] = math.floor((raw_Data["EIO_Capacity_Current"] / raw_Data["EIO_Capacity_Max"]) * 100)
	calculated_Data["reactor_Fuel_Percent"] = math.floor(((raw_Data["reactor_Fuel_Info"]["fuelAmount"] + raw_Data["reactor_Fuel_Info"]["wasteAmount"]) / raw_Data["reactor_Fuel_Info"]["fuelCapacity"]) * 100)
	--calculated_Data["waste_Percent"] = math.floor((raw_Data["reactor_Fuel_Info"]["wasteAmount"] / raw_Data["reactor_Fuel_Info"]["fuelCapacity"]) * 100)
	
	if display_Settings["ME_Storage_Support"] then
		calculated_Data["total_Reactor_Fuel"] = raw_Data["reactor_Fuel_Info"]["fuelAmount"] + raw_Data["ME_Yellorium_Amount"] * 1000
	else
		calculated_Data["total_Reactor_Fuel"] = raw_Data["reactor_Fuel_Info"]["fuelAmount"]
	end
	
	if raw_Data["reactor_Active"] then
		local time_To_Reactor_Stop = (((calculated_Data["total_Reactor_Fuel"] / raw_Data["reactor_Fuel_Info"]["fuelConsumedLastTick"]) / 25) / 60)
		
		if time_To_Reactor_Stop < 60 then
			calculated_Data["out_Of_Fuel"] = math.floor(time_To_Reactor_Stop)
			calculated_Data["time_Suffix"] = " min"
		elseif time_To_Reactor_Stop > 3600 then
			calculated_Data["out_Of_Fuel"] = math.floor(time_To_Reactor_Stop / 3600)
			calculated_Data["time_Suffix"] = " days"
		elseif time_To_Reactor_Stop >= 60 then
			calculated_Data["out_Of_Fuel"] = math.floor(time_To_Reactor_Stop / 60)
			calculated_Data["time_Suffix"] = " hours"
		end
	else
		calculated_Data["out_Of_Fuel"] = "---"
		calculated_Data["time_Suffix"] = " "
	end
	
	if raw_Data["reactor_Energy_Info"]["energyProducedLastTick"] > 1000 then
		calculated_Data["energy_Generation"] = math.floor(raw_Data["reactor_Energy_Info"]["energyProducedLastTick"] / 1000)
		calculated_Data["energy_Suffix"] = " kRF/t"
	else
		calculated_Data["energy_Generation"] = math.floor(raw_Data["reactor_Energy_Info"]["energyProducedLastTick"])
		calculated_Data["energy_Suffix"] = " RF/t"
	end
	
	if display_Settings["ME_Storage_Support"] then
		calculated_Data["ME_Support_String"] = " (" .. raw_Data["ME_Yellorium_Amount"] .. "k mB in ME" .. ")"
	else
		calculated_Data["ME_Support_String"] = ""
	end
	
	time_Calculation()
end



function draw_On_Screen()
	term.clear()
	gpu.setForeground(0xffffff)
	local x, y = 1, 1
	
	local reactor_Name = "Reactor Name: " .. display_Settings["reactor_Name"]
	gpu.set(x, y, reactor_Name)
	y = y + 2
	
	gpu.set(x, y, "Reactor State: ")
	y = y + 2
	
	local reactor_Generation = "Generation: " .. calculated_Data["energy_Generation"] .. calculated_Data["energy_Suffix"]
	gpu.set(x, y, reactor_Generation)
	y = y + 2
	
	local available_Fuel = "Available Fuel: " .. math.floor(raw_Data["reactor_Fuel_Info"]["fuelAmount"]) .. " / " .. math.floor(raw_Data["reactor_Fuel_Info"]["fuelCapacity"]).. " mB"
	local available_Fuel_Percent = " (" .. calculated_Data["reactor_Fuel_Percent"] .. "%)"
	local available_Fuel_In_ME = calculated_Data["ME_Support_String"]
	gpu.set(x, y, available_Fuel .. available_Fuel_Percent .. available_Fuel_In_ME)
	y = y + 2

	--local waste_Percent = "Waste: " .. calculated_Data["waste_Percent"] .. "%"
	--gpu.set(x, y, waste_Percent)
	--y = y + 2	
	
	local reactor_Consumption = "Fuel Consume: " .. calculated_Data["fuel_Consume"] .. " Ingot / min"
	gpu.set(x, y, reactor_Consumption)
	y = y + 2
	
	local out_Of_Fuel = "Out Of Fuel: " .. calculated_Data["out_Of_Fuel"] .. calculated_Data["time_Suffix"]
	gpu.set(x, y, out_Of_Fuel)
	y = y + 2
	
	local reactor_Capacity = "Reactor Capacity: " .. calculated_Data["energy_Stored"] .. " kRF " .. "(" .. calculated_Data["energy_Percent"] .. "%)"
	gpu.set(x, y, reactor_Capacity)
	y = y + 2
	
	if display_Settings["EIO_Capacitor_Support"] then
		local EIO_Battery_Capacity = "Battery Capacity: " .. calculated_Data["EIO_Charge_Capacity"] .. " kRF " .. "(" .. calculated_Data["EIO_Charge_Percent"] .. "%)"
		gpu.set(x, y, EIO_Battery_Capacity)
		y = y + 2
	end

	local last_Time_On = "Reactor Last ON: " .. calculated_Data["last_On_Time"] .. calculated_Data["last_On_Suffix"]
	gpu.set(x, y, last_Time_On)
	y = y + 2
	
	if raw_Data["reactor_State"] == "on" then
		gpu.setForeground(0x00ff00)
		gpu.set(16, 3, "ON")
	elseif raw_Data["reactor_State"] == "off" then
		gpu.setForeground(0xff0000)
		gpu.set(16, 3, "OFF")
	elseif raw_Data["reactor_State"] == "storage_Mode" then
		gpu.setForeground(0xfffa00)
		gpu.set(16, 3, "Storage Mode")
	elseif raw_Data["reactor_State"] == "out_Of_Fuel" then
		gpu.setForeground(0xfffa00)
		gpu.set(16, 3, "Out Of Fuel")
	end
end



function resolution_Calculation()
	raw_Data["display_Resolution"]["x"] = 52
	raw_Data["display_Resolution"]["y"] = 15

	if display_Settings["EIO_Capacitor_Support"] then
		raw_Data["display_Resolution"]["y"] = raw_Data["display_Resolution"]["y"] + 2
	end
	
	gpu.setResolution(raw_Data["display_Resolution"]["x"], raw_Data["display_Resolution"]["y"])
end



support_Check()
resolution_Calculation()
term.clear()



while true do
	data_Collector()

	if raw_Data["reactor_Available"] then
		draw_On_Screen()
	end
	os.sleep(1)
end
