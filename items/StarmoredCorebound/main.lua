require "/items/gunsbound/animationkey.lua"
require "/scripts/vec2.lua"


animation = {step = 30, fixed = false, currentstep = 1, key = 1, tracks = {shoot = {{sound = {}, value ={}},{sound = {}, value = {}}}}, playing = nil, doneplaying = ""}

parts = {gun_x = 0, gun_y = 0, gun_rotation = 0}

transform = {
	gun = {}
}

gunConfig = {}
cooldown = 0
recoil = 0
lerpedrecoil = 0 --for visuals
smoke = 0
burstcount = 0
itemInfo = {}

function init()
	gunConfig = config.getParameter("gunConfig", {projectileType = "bullet-4", fireOffset = {0,0}, fireSpeed = 0.06, fireMode = "auto", recoilPower = 10, recoilRecovery = 4})
	animation = config.getParameter("animationKey", {step = 30, fixed = false, currentstep = 1, key = 1, tracks = {shoot = {{sound = {}, value ={}},{sound = {}, value = {}}}}, playing = nil, doneplaying = ""})
	parts = config.getParameter("parts", {gun_x = 0, gun_y = 0, gun_rotation = 0})
	parts.armangle = 0
	itemInfo = root.itemConfig({count = 1, name = config.getParameter("itemName")}, 1, 01)
	transform = root.assetJson(itemInfo.directory.."gunsprite.animation").transformationGroups
	updateAnimation()
	updateAim()
end

function update(dt, fireMode, shiftHeld)

	if cooldown > 0 then
		cooldown = cooldown - dt
	else
		activeItem.setRecoil(false)
	end
	
	if smoke > 0 and cooldown <= 0 then
		smoke = smoke - dt
		if smoke < 1.5 and gunConfig.smokeEffect then
			animator.burstParticleEmitter("smoke")
		end
	end
	
	if mcontroller.crouching() then
		recoil = recoil - (recoil / (gunConfig.recoilRecovery * 0.8))
	else
		recoil = recoil - (recoil / gunConfig.recoilRecovery)
	end
	updateFire(dt, fireMode, shiftHeld)
	updateAnimation()
	updateAim()
	updateDrawable()
end

function updateFire(dt, fireMode, shiftHeld)
	if fireMode == "primary" and gunConfig.fireMode == "auto" and cooldown <= 0 then
		shoot()
	end
	
	if fireMode == "primary" and gunConfig.fireMode == "semi" and cooldown <= 0 and not self.onetap then
		shoot()
		self.onetap = true
		elseif self.onetap and fireMode ~= "primary" then
		self.onetap = nil
	end
	
	if fireMode == "primary" and gunConfig.fireMode == "burst" and cooldown <= 0 and burstcount <= 0 then
		burstcount = gunConfig.burstAmount or 3
	end
	
	if burstcount > 0 and cooldown <= 0 then
		burstcount = burstcount - 1
		shoot()
		if burstcount == 0 then
			cooldown = gunConfig.burstCooldown or gunConfig.fireSpeed * 2
		end
	end
end

function updateDrawable()
	for i,v in pairs(transform) do
		animator.resetTransformationGroup(i)
		if parts[i.."_rotation"] then
			if parts[i.."_xRot"] and parts[i.."_yRot"] then
				animator.rotateTransformationGroup(i, math.rad(parts[i.."_rotation"]), {parts[i.."_xRot"], parts[i.."_yRot"]})
			else
				animator.rotateTransformationGroup(i, math.rad(parts[i.."_rotation"]))
			end
		end
		if parts[i.."_x"] and parts[i.."_y"] then
			animator.translateTransformationGroup(i, {parts[i.."_x"], parts[i.."_y"]})
		end
	end
	animator.resetTransformationGroup("muzzle")
	animator.translateTransformationGroup("muzzle", gunConfig.fireOffset or {0,0})
	animator.resetTransformationGroup("case")
	animator.translateTransformationGroup("case", gunConfig.shellOffset or {0,0})
end

function updateAim()
	self.aimAngle, self.facingDirection = activeItem.aimAngleAndDirection(0, vec2.sub(activeItem.ownerAimPosition(), {0, gunConfig.fireOffset[2]}))
	activeItem.setFacingDirection(self.facingDirection)
	lerpedrecoil = lerp(lerpedrecoil, recoil, 3)
	activeItem.setArmAngle(self.aimAngle + math.rad(lerpedrecoil)	+ math.rad(parts.armangle))
end

function lerp(value, to, speed)
return value + ((to - value ) / speed ) 
end

function shoot()
	if gunConfig.compatibleAmmo then
		local itemammo = nil
		for i,v in ipairs(gunConfig.compatibleAmmo) do
			if activeItem.ownerHasItem({count = 1, name = v}) then
				itemammo = activeItem.takeOwnerItem({count = 1, name = v})
				if not itemammo.parameters.projectileType then --sometimes some doesnt show the config
					itemammo.parameters = root.assetJson(root.itemConfig({count = 1, name = v}).directory..v..".item")
				end
				break
			end
		end
		
		if itemammo then
			local projectile = "bullet-2"
			local projectileconf = {}
			
			
			if itemammo.parameters and itemammo.parameters.projectileType then
				projectile = itemammo.parameters.projectileType
			else
				projectile = gunConfig.projectileType or "bullet-2"
			end
			
			if itemammo.parameters and itemammo.parameters.projectileConfig then
				projectileconf = itemammo.parameters.projectileConfig
			else
				projectileconf = gunConfig.projectileConfig or {}
			end
			
			
			
			playAnimation("shoot")
			world.spawnProjectile(
				projectile,
				offset(),
				activeItem.ownerEntityId(),
				aim(),
				false,
				projectileconf
			)
			smoke = 2
			recoil = recoil + gunConfig.recoilPower
			cooldown = gunConfig.fireSpeed or 0.1
			activeItem.setRecoil(true)
			animator.setAnimationState("firing", "fire")
			if gunConfig.shellEffect then
				animator.burstParticleEmitter("case")
			end
			for i,v in pairs(gunConfig.gunSounds) do
				if animator.hasSound(v) then
					animator.playSound(v)
				end
			end
		else
			if animator.hasSound("dry") then
				animator.playSound("dry")
			end
			smoke = 0
			activeItem.setRecoil(false)
			cooldown = 0.5
			recoil = recoil + 1
		end
		
	end
end

function posi(val)
if val > 0 then
return val
else
return -val
end
end

function offset()
local offset = {mcontroller.position()[1] + vec2.rotate(activeItem.handPosition(gunConfig.fireOffset), mcontroller.rotation())[1], mcontroller.position()[2] + vec2.rotate(activeItem.handPosition(gunConfig.fireOffset), mcontroller.rotation())[2]}
return offset
end

function aim()
  local randoms = 0
  local inaccuracy = gunConfig.inaccuracy or 45
  if not (mcontroller.xVelocity() < 1 and mcontroller.xVelocity() > -1) then
  randoms = (math.random (0,20 * math.floor(math.min(posi(mcontroller.xVelocity()), inaccuracy))) - 10 * math.floor(math.min(posi(mcontroller.xVelocity()), inaccuracy))) / 10
  end
  if not mcontroller.onGround() then
  randoms = (math.random (0,20 * math.floor(math.min(inaccuracy, inaccuracy))) - 10 * math.floor(math.min(inaccuracy, inaccuracy))) / 10
  end
  local aimVector = vec2.rotate({1, 0}, self.aimAngle + math.rad(recoil) + math.rad(parts.armangle) + math.rad(randoms))
  aimVector[1] = aimVector[1] * self.facingDirection
  aimVector[2] = aimVector[2]
  return aimVector
end