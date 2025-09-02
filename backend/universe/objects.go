package universe

import (
	"celestial-backend/utils"
	"fmt"
	"log"
	"math"
	"math/rand"
	"time"
)

type ObjectType string

const (
	ObjectTypeShip      ObjectType = "ship"
	ObjectTypePlanet    ObjectType = "planet"
	ObjectTypeStation   ObjectType = "station"
	ObjectTypeAsteroid  ObjectType = "asteroid"
	ObjectTypeBlackHole ObjectType = "black_hole"
	ObjectTypeMine      ObjectType = "mine"
	ObjectTypeNebula    ObjectType = "nebula"
	ObjectTypeTorpedo   ObjectType = "torpedo"
	ObjectTypeBeam      ObjectType = "beam"
	ObjectTypeExplosion ObjectType = "explosion"
)

type Object struct {
	ID           string                 `json:"id"`
	Type         ObjectType             `json:"type"`
	Name         string                 `json:"name"`
	Position     utils.Vector3          `json:"position"`
	Velocity     utils.Vector3          `json:"velocity"`
	Acceleration utils.Vector3          `json:"acceleration"`
	Rotation     utils.Quaternion       `json:"rotation"`
	AngularVel   utils.Vector3          `json:"angular_velocity"`
	Scale        utils.Vector3          `json:"scale"`
	Health       float64                `json:"health"`
	MaxHealth    float64                `json:"max_health"`
	Shield       float64                `json:"shield"`
	MaxShield    float64                `json:"max_shield"`
	Power        float64                `json:"power"`
	MaxPower     float64                `json:"max_power"`
	Mass         float64                `json:"mass"`
	Radius       float64                `json:"radius"`
	IsPlayerShip bool                   `json:"is_player_ship"`
	IsStatic     bool                   `json:"is_static"`
	CreatedAt    time.Time              `json:"created_at"`
	TTL          float64                `json:"ttl"`
	Properties   map[string]interface{} `json:"properties"`
}

type Ship struct {
	Object
	EngineThrust float64           `json:"engine_thrust"`
	MaxThrust    float64           `json:"max_thrust"`
	TurnRate     float64           `json:"turn_rate"`
	Weapons      []Weapon          `json:"weapons"`
	ShieldRegen  float64           `json:"shield_regen"`
	PowerRegen   float64           `json:"power_regen"`
	Crew         int               `json:"crew"`
	Systems      map[string]System `json:"systems"`
	SensorRange  float64           `json:"sensor_range"`
	Transponder  string            `json:"transponder"`
	Faction      string            `json:"faction"`
	AutoPilot    AutoPilotState    `json:"autopilot"`
	DamageReport []DamageEntry     `json:"damage_report"`
}

type Weapon struct {
	ID           string        `json:"id"`
	Type         string        `json:"type"`
	Name         string        `json:"name"`
	Damage       float64       `json:"damage"`
	Range        float64       `json:"range"`
	CooldownTime float64       `json:"cooldown_time"`
	LastFired    time.Time     `json:"last_fired"`
	PowerCost    float64       `json:"power_cost"`
	Position     utils.Vector3 `json:"position"`
	Direction    utils.Vector3 `json:"direction"`
	Ammunition   int           `json:"ammunition"`
	MaxAmmo      int           `json:"max_ammo"`
}

type System struct {
	Name       string  `json:"name"`
	Health     float64 `json:"health"`
	MaxHealth  float64 `json:"max_health"`
	PowerDraw  float64 `json:"power_draw"`
	Efficiency float64 `json:"efficiency"`
	Priority   int     `json:"priority"`
	IsOnline   bool    `json:"is_online"`
	IsCritical bool    `json:"is_critical"`
	RepairTime float64 `json:"repair_time"`
	RepairCost float64 `json:"repair_cost"`
}

type AutoPilotState struct {
	Enabled        bool          `json:"enabled"`
	Mode           string        `json:"mode"`
	TargetPosition utils.Vector3 `json:"target_position"`
	TargetHeading  float64       `json:"target_heading"`
	TargetSpeed    float64       `json:"target_speed"`
	FollowTargetID string        `json:"follow_target_id"`
	StationKeeping bool          `json:"station_keeping"`
	CollisionAvoid bool          `json:"collision_avoid"`
}

type DamageEntry struct {
	System      string    `json:"system"`
	Severity    float64   `json:"severity"`
	Description string    `json:"description"`
	Timestamp   time.Time `json:"timestamp"`
	Repairable  bool      `json:"repairable"`
}

func NewObject(id string, objType ObjectType, name string) *Object {
	return &Object{
		ID:           id,
		Type:         objType,
		Name:         name,
		Position:     utils.Vector3{},
		Velocity:     utils.Vector3{},
		Acceleration: utils.Vector3{},
		Rotation:     utils.Quaternion{W: 1},
		AngularVel:   utils.Vector3{},
		Scale:        utils.Vector3{X: 1, Y: 1, Z: 1},
		Health:       100,
		MaxHealth:    100,
		Shield:       0,
		MaxShield:    0,
		Power:        100,
		MaxPower:     100,
		Mass:         1000,
		Radius:       10,
		IsPlayerShip: false,
		IsStatic:     false,
		CreatedAt:    time.Now(),
		TTL:          -1,
		Properties:   make(map[string]interface{}),
	}
}

func NewPlayerShip(id, name string, position utils.Vector3) *Ship {
	obj := NewObject(id, ObjectTypeShip, name)
	obj.Position = position
	obj.IsPlayerShip = true
	obj.Mass = 50000
	obj.Radius = 50
	obj.MaxShield = 1000
	obj.Shield = 1000
	obj.MaxPower = 2000
	obj.Power = 2000

	ship := &Ship{
		Object:       *obj,
		EngineThrust: 0,
		MaxThrust:    10000,
		TurnRate:     30,
		ShieldRegen:  10,
		PowerRegen:   50,
		Crew:         200,
		SensorRange:  50000,
		Transponder:  "USS Celestial",
		Faction:      "Federation",
		Systems:      make(map[string]System),
		AutoPilot: AutoPilotState{
			Enabled:        false,
			Mode:           "manual",
			CollisionAvoid: true,
		},
		DamageReport: make([]DamageEntry, 0),
	}

	ship.initializeSystems()
	ship.initializeWeapons()

	log.Printf("Player ship created: %s", ship.ID)

	return ship
}

func (s *Ship) initializeSystems() {
	systems := []System{
		{Name: "engines", Health: 100, MaxHealth: 100, PowerDraw: 200, Efficiency: 1.0, Priority: 1, IsOnline: true, IsCritical: true},
		{Name: "shields", Health: 100, MaxHealth: 100, PowerDraw: 150, Efficiency: 1.0, Priority: 2, IsOnline: true, IsCritical: false},
		{Name: "weapons", Health: 100, MaxHealth: 100, PowerDraw: 300, Efficiency: 1.0, Priority: 3, IsOnline: true, IsCritical: false},
		{Name: "sensors", Health: 100, MaxHealth: 100, PowerDraw: 100, Efficiency: 1.0, Priority: 4, IsOnline: true, IsCritical: false},
		{Name: "communications", Health: 100, MaxHealth: 100, PowerDraw: 50, Efficiency: 1.0, Priority: 5, IsOnline: true, IsCritical: false},
		{Name: "life_support", Health: 100, MaxHealth: 100, PowerDraw: 75, Efficiency: 1.0, Priority: 1, IsOnline: true, IsCritical: true},
		{Name: "computer", Health: 100, MaxHealth: 100, PowerDraw: 125, Efficiency: 1.0, Priority: 2, IsOnline: true, IsCritical: true},
	}

	for _, sys := range systems {
		s.Systems[sys.Name] = sys
	}
}

func (s *Ship) initializeWeapons() {
	s.Weapons = []Weapon{
		{
			ID:           "phaser_array_1",
			Type:         "phaser",
			Name:         "Forward Phaser Array",
			Damage:       150,
			Range:        25000,
			CooldownTime: 2.0,
			PowerCost:    100,
			Position:     utils.Vector3{X: 0, Y: 0, Z: 25},
			Direction:    utils.Vector3{X: 0, Y: 0, Z: 1},
			Ammunition:   -1,
			MaxAmmo:      -1,
		},
		{
			ID:           "torpedo_launcher_1",
			Type:         "torpedo",
			Name:         "Forward Torpedo Launcher",
			Damage:       500,
			Range:        50000,
			CooldownTime: 5.0,
			PowerCost:    50,
			Position:     utils.Vector3{X: 0, Y: -5, Z: 30},
			Direction:    utils.Vector3{X: 0, Y: 0, Z: 1},
			Ammunition:   20,
			MaxAmmo:      20,
		},
	}
}

func NewPlanet(id, name string, position utils.Vector3, radius float64) *Object {
	obj := NewObject(id, ObjectTypePlanet, name)
	obj.Position = position
	obj.Radius = radius
	obj.Mass = radius * radius * radius * 1000
	obj.IsStatic = true
	obj.Scale = utils.Vector3{X: radius / 100, Y: radius / 100, Z: radius / 100}

	log.Printf("Planet created: %s", obj.ID)
	return obj
}

func NewStation(id, name string, position utils.Vector3) *Object {
	obj := NewObject(id, ObjectTypeStation, name)
	obj.Position = position
	obj.Radius = 200
	obj.Mass = 100000
	obj.IsStatic = true
	obj.MaxShield = 5000
	obj.Shield = 5000
	obj.Health = 2000
	obj.MaxHealth = 2000

	log.Printf("Station created: %s", obj.ID)
	return obj
}

func NewAsteroid(id string, position utils.Vector3) *Object {
	obj := NewObject(id, ObjectTypeAsteroid, fmt.Sprintf("Asteroid-%s", id[:8]))
	obj.Position = position
	obj.Radius = 5 + rand.Float64()*20
	obj.Mass = obj.Radius * obj.Radius * 100
	obj.Velocity = utils.Vector3{
		X: (rand.Float64() - 0.5) * 100,
		Y: (rand.Float64() - 0.5) * 100,
		Z: (rand.Float64() - 0.5) * 100,
	}
	obj.AngularVel = utils.Vector3{
		X: (rand.Float64() - 0.5) * 2,
		Y: (rand.Float64() - 0.5) * 2,
		Z: (rand.Float64() - 0.5) * 2,
	}
	obj.Health = obj.Radius * 10
	obj.MaxHealth = obj.Health

	log.Printf("Asteroid created: %s", obj.ID)
	return obj
}

func NewBlackHole(id, name string, position utils.Vector3, mass float64) *Object {
	obj := NewObject(id, ObjectTypeBlackHole, name)
	obj.Position = position
	obj.Mass = mass
	obj.Radius = mass / 1000000
	obj.IsStatic = true
	obj.Properties["event_horizon"] = obj.Radius * 2.5
	obj.Properties["accretion_disk"] = obj.Radius * 10
	obj.Properties["gravitational_range"] = obj.Radius * 100

	log.Printf("Black hole created: %s", obj.ID)
	return obj
}

func NewTorpedo(id string, position, velocity utils.Vector3, targetID string, damage float64) *Object {
	obj := NewObject(id, ObjectTypeTorpedo, "Torpedo")
	obj.Position = position
	obj.Velocity = velocity
	obj.Radius = 2
	obj.Mass = 100
	obj.TTL = 30.0
	obj.Properties["target_id"] = targetID
	obj.Properties["damage"] = damage
	obj.Properties["proximity_trigger"] = 10.0
	obj.Properties["guidance"] = true

	log.Printf("Torpedo created: %s", obj.ID)
	return obj
}

func NewMine(id string, position utils.Vector3, damage float64) *Object {
	obj := NewObject(id, ObjectTypeMine, "Space Mine")
	obj.Position = position
	obj.Radius = 5
	obj.Mass = 500
	obj.IsStatic = true
	obj.Properties["damage"] = damage
	obj.Properties["trigger_range"] = 50.0
	obj.Properties["armed"] = true

	log.Printf("Mine created: %s", obj.ID)
	return obj
}

func NewNebula(id, name string, position utils.Vector3, radius float64) *Object {
	obj := NewObject(id, ObjectTypeNebula, name)
	obj.Position = position
	obj.Radius = radius
	obj.Mass = 0
	obj.IsStatic = true
	obj.Properties["interference"] = 0.7
	obj.Properties["visibility"] = 0.3
	obj.Properties["sensor_dampening"] = 0.8

	log.Printf("Nebula created: %s", obj.ID)
	return obj
}

func (obj *Object) Update(deltaTime float64) {
	if obj.IsStatic {
		return
	}

	if obj.TTL > 0 {
		obj.TTL -= deltaTime
	}

	obj.Velocity = obj.Velocity.Add(obj.Acceleration.Mul(deltaTime))
	obj.Position = obj.Position.Add(obj.Velocity.Mul(deltaTime))

	if obj.AngularVel.Length() > 0 {
		angle := obj.AngularVel.Length() * deltaTime
		if angle > 0 {
			axis := obj.AngularVel.Normalize()
			rotation := utils.QuaternionFromAxisAngle(axis, angle)
			obj.Rotation = obj.Rotation.Multiply(rotation).Normalize()
		}
	}

	obj.Acceleration = utils.Vector3{}
}

func (obj *Object) ApplyForce(force utils.Vector3) {
	if obj.Mass > 0 {
		acceleration := force.Div(obj.Mass)
		obj.Acceleration = obj.Acceleration.Add(acceleration)
	}
}

func (obj *Object) ApplyTorque(torque utils.Vector3) {
	obj.AngularVel = obj.AngularVel.Add(torque.Mul(0.01))
}

func (obj *Object) GetDistance(other *Object) float64 {
	return obj.Position.Distance(other.Position)
}

func (obj *Object) IsExpired() bool {
	return obj.TTL > 0 && obj.TTL <= 0
}

func (obj *Object) TakeDamage(damage float64) {
	if obj.Shield > 0 {
		shieldDamage := math.Min(damage, obj.Shield)
		obj.Shield -= shieldDamage
		damage -= shieldDamage
	}

	if damage > 0 {
		obj.Health = math.Max(0, obj.Health-damage)
	}
}

func (obj *Object) IsDestroyed() bool {
	return obj.Health <= 0
}

func (s *Ship) UpdateSystems(deltaTime float64) {
	totalPowerDraw := 0.0
	for _, system := range s.Systems {
		if system.IsOnline {
			totalPowerDraw += system.PowerDraw * system.Efficiency
		}
	}

	powerDeficit := totalPowerDraw - s.Power
	if powerDeficit > 0 {
		s.shutdownNonCriticalSystems()
	}

	s.Power = math.Max(0, s.Power-totalPowerDraw*deltaTime)
	s.Power = math.Min(s.MaxPower, s.Power+s.PowerRegen*deltaTime)

	if s.Shield < s.MaxShield {
		shieldSystem := s.Systems["shields"]
		if shieldSystem.IsOnline && shieldSystem.Health > 50 {
			regenRate := s.ShieldRegen * (shieldSystem.Health / 100.0) * shieldSystem.Efficiency
			s.Shield = math.Min(s.MaxShield, s.Shield+regenRate*deltaTime)
		}
	}
}

func (s *Ship) shutdownNonCriticalSystems() {
	for name, system := range s.Systems {
		if !system.IsCritical && system.IsOnline {
			system.IsOnline = false
			s.Systems[name] = system
			break
		}
	}
}

func (s *Ship) CanFireWeapon(weaponID string) bool {
	for _, weapon := range s.Weapons {
		if weapon.ID == weaponID {
			timeSinceLastFired := time.Since(weapon.LastFired).Seconds()
			hasAmmo := weapon.Ammunition == -1 || weapon.Ammunition > 0
			hasPower := s.Power >= weapon.PowerCost
			weaponsOnline := s.Systems["weapons"].IsOnline

			return timeSinceLastFired >= weapon.CooldownTime && hasAmmo && hasPower && weaponsOnline
		}
	}
	return false
}

func (s *Ship) FireWeapon(weaponID string) bool {
	if !s.CanFireWeapon(weaponID) {
		return false
	}

	for i, weapon := range s.Weapons {
		if weapon.ID == weaponID {
			s.Weapons[i].LastFired = time.Now()
			if weapon.Ammunition > 0 {
				s.Weapons[i].Ammunition--
			}
			s.Power -= weapon.PowerCost
			return true
		}
	}
	return false
}

func (s *Ship) GetSystemEfficiency(systemName string) float64 {
	if system, exists := s.Systems[systemName]; exists {
		if !system.IsOnline {
			return 0.0
		}
		return (system.Health / system.MaxHealth) * system.Efficiency
	}
	return 0.0
}

func (s *Ship) RepairSystem(systemName string, repairAmount float64) {
	if system, exists := s.Systems[systemName]; exists {
		system.Health = math.Min(system.MaxHealth, system.Health+repairAmount)
		s.Systems[systemName] = system
	}
}

func (s *Ship) DamageSystem(systemName string, damage float64) {
	if system, exists := s.Systems[systemName]; exists {
		system.Health = math.Max(0, system.Health-damage)
		if system.Health <= 0 && system.IsOnline {
			system.IsOnline = false
		}
		s.Systems[systemName] = system

		damageEntry := DamageEntry{
			System:      systemName,
			Severity:    damage,
			Description: fmt.Sprintf("%s damaged: %.1f points", systemName, damage),
			Timestamp:   time.Now(),
			Repairable:  system.Health > 0,
		}
		s.DamageReport = append(s.DamageReport, damageEntry)
	}
}

func (s *Ship) SetAutoPilot(mode string, target interface{}) {
	s.AutoPilot.Mode = mode
	s.AutoPilot.Enabled = true

	switch mode {
	case "position":
		if pos, ok := target.(utils.Vector3); ok {
			s.AutoPilot.TargetPosition = pos
		}
	case "heading":
		if heading, ok := target.(float64); ok {
			s.AutoPilot.TargetHeading = heading
		}
	case "follow":
		if targetID, ok := target.(string); ok {
			s.AutoPilot.FollowTargetID = targetID
		}
	case "station_keeping":
		s.AutoPilot.StationKeeping = true
	}
}

func (s *Ship) DisableAutoPilot() {
	s.AutoPilot.Enabled = false
	s.AutoPilot.Mode = "manual"
	s.AutoPilot.TargetPosition = utils.Vector3{}
	s.AutoPilot.TargetHeading = 0
	s.AutoPilot.FollowTargetID = ""
	s.AutoPilot.StationKeeping = false
}
