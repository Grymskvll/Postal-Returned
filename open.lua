Postal.open = {}

local wait_for_update, open, process, inventory_count

local controller = (function()
	local controller
	return function()
		controller = controller or Postal.control.controller()
		return controller
	end
end)()

function wait_for_update(k)
	return controller().wait(function() return true end, k)
end

function Postal.open.start(selected, callback, mode)
	Postal.control.on_next_update(function()
		process(selected, function()
		callback()
		end, mode)
	end)
end

function Postal.open.stop()
	Postal.control.on_next_update(function()
		controller().reset()
	end)
end

function process(selected, k, mode)
	if getn(selected) == 0 then
		return k()
	else
		local index = selected[1]
		
		local inbox_count = GetInboxNumItems()
		if mode == "open" then
			open(index, inbox_count, function(skipIndex)
				tremove(selected, 1)
				
				if not skipIndex then
					for i, _ in selected do
						selected[i] = selected[i] - 1
					end
				end
				return process(selected, k, mode)
			end)
		elseif mode == "return" then
			returnmail(index, inbox_count, function(skipIndex)
				tremove(selected, 1)
				
				if not skipIndex then
					for i, _ in selected do
						selected[i] = selected[i] - 1
					end
				end
				return process(selected, k, mode)
			end)
		end
	end
end

function returnmail(i, inbox_count, k)
	wait_for_update(function()
		local _, _, _, _, _, _, _, _, _, wasReturned = GetInboxHeaderInfo(i)
		if GetInboxNumItems() < inbox_count then
			return k(false)
		elseif wasReturned then
			return k(true)
		else
			local inbox_count_before = GetInboxNumItems()
			ReturnInboxItem(i)
			controller().wait(function() return GetInboxNumItems() < inbox_count_before end, function()
			return returnmail(i, inbox_count, k)
			end)
		end
	end)
end

function open(i, inbox_count, k)
	wait_for_update(function()
		local _, _, _, _, money, COD_amount, _, has_item = GetInboxHeaderInfo(i)
		if GetInboxNumItems() < inbox_count then
			return k(false)
		elseif  COD_amount > 0 then
			return k(true)
		elseif has_item then
			local inventory_count_before = inventory_count()
			TakeInboxItem(i)
			controller().wait(function() return inventory_count() > inventory_count_before end, function()
			return open(i, inbox_count, k)
			end)
		elseif money > 0 then
			local money_before = GetMoney()
			TakeInboxMoney(i)
			controller().wait(function() return GetMoney() > money_before end, function()
			return open(i, inbox_count, k)
			end)
		else
			local inbox_count_before = GetInboxNumItems()
			DeleteInboxItem(i)
			controller().wait(function() return GetInboxNumItems() < inbox_count_before end, function()
			return open(i, inbox_count, k)
			end)
		end
	end)
end

function inventory_count()
	local acc = 0
	for bag = 0, 4 do
		if GetBagName(bag) then
			for slot = 1, GetContainerNumSlots(bag) do
				local _, count = GetContainerItemInfo(bag, slot)
				acc = acc + (count or 0)
			end
		end
	end
	return acc
end