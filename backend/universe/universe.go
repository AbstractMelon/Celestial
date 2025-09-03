package universe

import (
	"celestial-backend/networking"
	"celestial-backend/utils"
	"fmt"
	"math/rand"
	"sync"
	"time"
)

type VisualEffect struct {
	ID         string                 `json:"id"`
	Type       string                 `json:"type"`
	Position   utils.Vector3          `json:"position"`
	Direction  utils.Vector3          `json:"direction"`
	Color      [3]float64             `json:"color"`
	Intensity  float64                `json:"intensity"`
	Duration   float64                `json:"duration"`
	TimeLeft   float64                `json:"time_left"`
	Properties map[string]interface{} `json:"properties"`
}

type Universe struct {
	Objects          map[string]*Object
	Ships            map[string]*Ship
	Effects          map[string]*VisualEffect
	Physics          *PhysicsEngine
	PlayerShipID     string
	TimeAcceleration float64
	AlertLevel       int
	LastUpdateTime   time.Time
	TotalTime        float64
	mutex            sync.RWMutex
	eventCallbacks   []func(string, interface{})
	idCounter        int64
}

func NewUniverse() *Universe {
	u := &Universe{
		Objects:          make(map[string]*Object),
		Ships:            make(map[string]*Ship),
		Effects:          make(map[string]*VisualEffect),
		Physics:          NewPhysicsEngine(),
		PlayerShipID:     "",
		TimeAcceleration: 1.0,
		AlertLevel:       0,
		LastUpdateTime:   time.Now(),
		TotalTime:        0,
		eventCallbacks:   make([]func(string, interface{}), 0),
		idCounter:        1,
	}

	u.initializeDefaultScenario()
	return u
}

func (u *Universe) initializeDefaultScenario() {
	playerShip := NewPlayerShip("player_ship", "USS Astra", utils.Vector3{X: 0, Y: 0, Z: 0})
	u.AddShip(playerShip)
	u.PlayerShipID = playerShip.ID

	station := NewStation("starbase_1", "Deep Space Station Alpha", utils.Vector3{X: 5000, Y: 0, Z: 0})
	u.AddObject(station)

	planet := NewPlanet("planet_1", "Kepler-442b", utils.Vector3{X: -10000, Y: 0, Z: 5000}, 2000)
	u.AddObject(planet)

	for i := 0; i < 20; i++ {
		pos := utils.Vector3{
			X: (rand.Float64() - 0.5) * 50000,
			Y: (rand.Float64() - 0.5) * 10000,
			Z: (rand.Float64() - 0.5) * 50000,
		}
		asteroid := NewAsteroid(u.generateID("asteroid"), pos)
		u.AddObject(asteroid)
	}
}

func (u *Universe) generateID(prefix string) string {
	u.idCounter++
	return fmt.Sprintf("%s_%d", prefix, u.idCounter)
}

func (u *Universe) AddObject(obj *Object) {
	u.mutex.Lock()
	defer u.mutex.Unlock()

	u.Objects[obj.ID] = obj
	u.Physics.AddObject(obj)
	u.fireEvent("object_added", obj)
}

func (u *Universe) AddShip(ship *Ship) {
	u.mutex.Lock()
	defer u.mutex.Unlock()

	u.Ships[ship.ID] = ship
	u.Objects[ship.ID] = &ship.Object
	u.Physics.AddObject(&ship.Object)
	u.fireEvent("ship_added", ship)
}

func (u *Universe) RemoveObject(id string) {
	u.mutex.Lock()
	defer u.mutex.Unlock()

	if obj, exists := u.Objects[id]; exists {
		u.Physics.RemoveObject(obj)
		delete(u.Objects, id)
		delete(u.Ships, id)
		u.fireEvent("object_removed", id)
	}
}

func (u *Universe) GetObject(id string) *Object {
	u.mutex.RLock()
	defer u.mutex.RUnlock()
	return u.Objects[id]
}

func (u *Universe) GetShip(id string) *Ship {
	u.mutex.RLock()
	defer u.mutex.RUnlock()
	return u.Ships[id]
}

func (u *Universe) GetPlayerShip() *Ship {
	return u.GetShip(u.PlayerShipID)
}

func (u *Universe) Update() {
	u.mutex.Lock()
	defer u.mutex.Unlock()

	now := time.Now()
	deltaTime := now.Sub(u.LastUpdateTime).Seconds() * u.TimeAcceleration
	u.LastUpdateTime = now
	u.TotalTime += deltaTime

	for _, ship := range u.Ships {
		ship.UpdateSystems(deltaTime)
		u.updateAutoPilot(ship, deltaTime)
	}

	collisions := u.Physics.Update(deltaTime)
	for _, collision := range collisions {
		u.handleCollision(collision)
	}

	u.updateEffects(deltaTime)
	u.removeExpiredObjects()
	u.updateMineProximity()
}

func (u *Universe) updateAutoPilot(ship *Ship, deltaTime float64) {
	if !ship.AutoPilot.Enabled {
		return
	}

	switch ship.AutoPilot.Mode {
	case "position":
		u.autoPilotToPosition(ship, deltaTime)
	case "heading":
		u.autoPilotToHeading(ship, deltaTime)
	case "follow":
		u.autoPilotFollow(ship, deltaTime)
	case "station_keeping":
		u.autoPilotStationKeeping(ship, deltaTime)
	}

	if ship.AutoPilot.CollisionAvoid {
		u.autoPilotCollisionAvoidance(ship, deltaTime)
	}
}

func (u *Universe) autoPilotToPosition(ship *Ship, deltaTime float64) {
	toTarget := ship.AutoPilot.TargetPosition.Sub(ship.Position)
	distance := toTarget.Length()

	if distance < 100 {
		ship.DisableAutoPilot()
		return
	}

	direction := toTarget.Normalize()
	desiredVelocity := direction.Mul(ship.AutoPilot.TargetSpeed)
	velocityDiff := desiredVelocity.Sub(ship.Velocity)

	thrust := velocityDiff.Mul(ship.Mass * 0.1)
	maxThrust := ship.MaxThrust * ship.GetSystemEfficiency("engines")

	if thrust.Length() > maxThrust {
		thrust = thrust.Normalize().Mul(maxThrust)
	}

	ship.ApplyForce(thrust)
}

func (u *Universe) autoPilotToHeading(ship *Ship, deltaTime float64) {
	currentHeading := utils.RadiansToDegrees(ship.Rotation.RotateVector(utils.Vector3{Z: 1}).X)
	headingDiff := ship.AutoPilot.TargetHeading - currentHeading

	for headingDiff > 180 {
		headingDiff -= 360
	}
	for headingDiff < -180 {
		headingDiff += 360
	}

	if abs(headingDiff) < 1 {
		ship.DisableAutoPilot()
		return
	}

	turnDirection := 1.0
	if headingDiff < 0 {
		turnDirection = -1.0
	}

	turnRate := ship.TurnRate * ship.GetSystemEfficiency("engines") * deltaTime
	torque := utils.Vector3{Y: turnDirection * turnRate}
	ship.ApplyTorque(torque)
}

func (u *Universe) autoPilotFollow(ship *Ship, deltaTime float64) {
	targetObj := u.GetObject(ship.AutoPilot.FollowTargetID)
	if targetObj == nil {
		ship.DisableAutoPilot()
		return
	}

	followDistance := 500.0
	toTarget := targetObj.Position.Sub(ship.Position)
	distance := toTarget.Length()

	if distance > followDistance {
		ship.AutoPilot.TargetPosition = targetObj.Position.Sub(toTarget.Normalize().Mul(followDistance))
		u.autoPilotToPosition(ship, deltaTime)
	}
}

func (u *Universe) autoPilotStationKeeping(ship *Ship, deltaTime float64) {
	if ship.Velocity.Length() > 10 {
		dampingForce := ship.Velocity.Mul(-ship.Mass * 0.1)
		ship.ApplyForce(dampingForce)
	}
}

func (u *Universe) autoPilotCollisionAvoidance(ship *Ship, deltaTime float64) {
	avoidanceRange := 1000.0
	nearbyObjects := u.Physics.GetObjectsInRange(ship.Position, avoidanceRange)

	for _, obj := range nearbyObjects {
		if obj.ID == ship.ID || obj.IsStatic {
			continue
		}

		toObject := obj.Position.Sub(ship.Position)
		distance := toObject.Length()

		if distance < avoidanceRange {
			avoidDirection := toObject.Normalize().Mul(-1)
			avoidanceStrength := (avoidanceRange - distance) / avoidanceRange
			avoidanceForce := avoidDirection.Mul(ship.MaxThrust * avoidanceStrength * 0.5)
			ship.ApplyForce(avoidanceForce)
		}
	}
}

func (u *Universe) handleCollision(collision CollisionResult) {
	u.fireEvent("collision", collision)

	if collision.Object1.Type == ObjectTypeTorpedo || collision.Object2.Type == ObjectTypeTorpedo {
		torpedo := collision.Object1
		if collision.Object2.Type == ObjectTypeTorpedo {
			torpedo = collision.Object2
		}

		u.createExplosion(torpedo.Position, 200, [3]float64{1.0, 0.5, 0.0})
	}

	if collision.Object1.Type == ObjectTypeMine || collision.Object2.Type == ObjectTypeMine {
		mine := collision.Object1
		if collision.Object2.Type == ObjectTypeMine {
			mine = collision.Object2
		}
		u.createExplosion(mine.Position, 500, [3]float64{1.0, 0.2, 0.0})
	}
}

func (u *Universe) updateEffects(deltaTime float64) {
	for id, effect := range u.Effects {
		effect.TimeLeft -= deltaTime
		if effect.TimeLeft <= 0 {
			delete(u.Effects, id)
		} else {
			u.Effects[id] = effect
		}
	}
}

func (u *Universe) removeExpiredObjects() {
	toRemove := make([]string, 0)

	for id, obj := range u.Objects {
		if obj.IsExpired() || obj.IsDestroyed() {
			toRemove = append(toRemove, id)
		}
	}

	for _, id := range toRemove {
		if obj := u.Objects[id]; obj != nil && obj.IsDestroyed() {
			u.createExplosion(obj.Position, 300, [3]float64{1.0, 0.3, 0.0})
		}
		u.RemoveObject(id)
	}
}

func (u *Universe) updateMineProximity() {
	mines := u.Physics.GetObjectsByType(ObjectTypeMine)
	for _, mine := range mines {
		triggerRange, ok := mine.Properties["trigger_range"].(float64)
		if !ok {
			continue
		}

		armed, ok := mine.Properties["armed"].(bool)
		if !ok || !armed {
			continue
		}

		nearbyObjects := u.Physics.GetObjectsInRange(mine.Position, triggerRange)
		for _, obj := range nearbyObjects {
			if obj.ID != mine.ID && obj.Type == ObjectTypeShip {
				if damage, ok := mine.Properties["damage"].(float64); ok {
					obj.TakeDamage(damage)
				}
				u.createExplosion(mine.Position, 500, [3]float64{1.0, 0.2, 0.0})
				mine.Health = 0
				break
			}
		}
	}
}

func (u *Universe) FireWeapon(shipID, weaponID, targetID string, targetPosition *utils.Vector3) bool {
	ship := u.GetShip(shipID)
	if ship == nil || !ship.CanFireWeapon(weaponID) {
		return false
	}

	if !ship.FireWeapon(weaponID) {
		return false
	}

	var weapon *Weapon
	for _, w := range ship.Weapons {
		if w.ID == weaponID {
			weapon = &w
			break
		}
	}

	if weapon == nil {
		return false
	}

	worldPos := ship.Position.Add(ship.Rotation.RotateVector(weapon.Position))
	worldDir := ship.Rotation.RotateVector(weapon.Direction)

	switch weapon.Type {
	case "phaser":
		u.createPhaserBeam(worldPos, worldDir, weapon, targetPosition)
	case "torpedo":
		u.createTorpedo(worldPos, worldDir, weapon, targetID, targetPosition)
	}

	return true
}

func (u *Universe) createPhaserBeam(position, direction utils.Vector3, weapon *Weapon, targetPos *utils.Vector3) {
	var endPos utils.Vector3

	if targetPos != nil {
		endPos = *targetPos
	} else {
		hit := u.Physics.RaycastHit(position, direction, weapon.Range)
		if hit != nil {
			endPos = hit.Position
			hit.TakeDamage(weapon.Damage)
		} else {
			endPos = position.Add(direction.Mul(weapon.Range))
		}
	}

	effect := &VisualEffect{
		ID:        u.generateID("phaser"),
		Type:      "phaser_beam",
		Position:  position,
		Direction: endPos.Sub(position).Normalize(),
		Color:     [3]float64{1.0, 0.2, 0.2},
		Intensity: 1.0,
		Duration:  0.5,
		TimeLeft:  0.5,
		Properties: map[string]interface{}{
			"end_position": endPos,
			"width":        2.0,
		},
	}

	u.Effects[effect.ID] = effect
}

func (u *Universe) createTorpedo(position, direction utils.Vector3, weapon *Weapon, targetID string, targetPos *utils.Vector3) {
	velocity := direction.Mul(1000)
	if targetPos != nil {
		toTarget := targetPos.Sub(position).Normalize()
		velocity = toTarget.Mul(1000)
	}

	torpedo := NewTorpedo(u.generateID("torpedo"), position, velocity, targetID, weapon.Damage)
	u.AddObject(torpedo)

	trail := &VisualEffect{
		ID:        u.generateID("torpedo_trail"),
		Type:      "torpedo_trail",
		Position:  position,
		Direction: direction,
		Color:     [3]float64{0.2, 0.5, 1.0},
		Intensity: 0.8,
		Duration:  2.0,
		TimeLeft:  2.0,
		Properties: map[string]interface{}{
			"torpedo_id": torpedo.ID,
		},
	}

	u.Effects[trail.ID] = trail
}

func (u *Universe) createExplosion(position utils.Vector3, force float64, color [3]float64) {
	u.Physics.ApplyExplosion(position, force, 200)

	explosion := &VisualEffect{
		ID:        u.generateID("explosion"),
		Type:      "explosion",
		Position:  position,
		Direction: utils.Vector3{},
		Color:     color,
		Intensity: 1.0,
		Duration:  3.0,
		TimeLeft:  3.0,
		Properties: map[string]interface{}{
			"force":  force,
			"radius": 200.0,
		},
	}

	u.Effects[explosion.ID] = explosion
}

func (u *Universe) SetTimeAcceleration(factor float64) {
	u.mutex.Lock()
	defer u.mutex.Unlock()
	u.TimeAcceleration = utils.Clamp(factor, 0.1, 10.0)
}

func (u *Universe) SetAlertLevel(level int) {
	u.mutex.Lock()
	defer u.mutex.Unlock()
	u.AlertLevel = int(utils.Clamp(float64(level), 0, 3))
	u.fireEvent("alert_level_changed", level)
}

func (u *Universe) GetState() *networking.UniverseState {
	u.mutex.RLock()
	defer u.mutex.RUnlock()

	objects := make([]networking.UniverseObject, 0, len(u.Objects))
	for _, obj := range u.Objects {
		netObj := networking.UniverseObject{
			ID:           obj.ID,
			Type:         networking.ObjectType(obj.Type),
			Name:         obj.Name,
			Position:     obj.Position,
			Velocity:     obj.Velocity,
			Rotation:     obj.Rotation,
			Scale:        obj.Scale,
			Health:       obj.Health,
			MaxHealth:    obj.MaxHealth,
			Shield:       obj.Shield,
			MaxShield:    obj.MaxShield,
			Power:        obj.Power,
			MaxPower:     obj.MaxPower,
			Mass:         obj.Mass,
			Radius:       obj.Radius,
			IsPlayerShip: obj.IsPlayerShip,
			Properties:   obj.Properties,
		}
		objects = append(objects, netObj)
	}

	effects := make([]networking.VisualEffect, 0, len(u.Effects))
	for _, effect := range u.Effects {
		netEffect := networking.VisualEffect{
			ID:         effect.ID,
			Type:       effect.Type,
			Position:   effect.Position,
			Direction:  effect.Direction,
			Color:      effect.Color,
			Intensity:  effect.Intensity,
			Duration:   effect.Duration,
			TimeLeft:   effect.TimeLeft,
			Properties: effect.Properties,
		}
		effects = append(effects, netEffect)
	}

	return &networking.UniverseState{
		Objects:          objects,
		Effects:          effects,
		PlayerShipID:     u.PlayerShipID,
		TimeAcceleration: u.TimeAcceleration,
		AlertLevel:       int(u.AlertLevel),
		Timestamp:        time.Now(),
	}
}

func (u *Universe) AddEventCallback(callback func(string, interface{})) {
	u.eventCallbacks = append(u.eventCallbacks, callback)
}

func (u *Universe) fireEvent(eventType string, data interface{}) {
	for _, callback := range u.eventCallbacks {
		callback(eventType, data)
	}
}

func abs(x float64) float64 {
	if x < 0 {
		return -x
	}
	return x
}
