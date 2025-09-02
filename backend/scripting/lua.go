package scripting

import (
	"celestial-backend/universe"
	"celestial-backend/utils"
	"fmt"
	"log"
	"time"

	lua "github.com/yuin/gopher-lua"
	luar "layeh.com/gopher-luar"
)

type LuaEngine struct {
	state    *lua.LState
	universe *universe.Universe
	triggers map[string]*Trigger
	events   map[string][]lua.LValue
	missions map[string]*Mission
}

type Trigger struct {
	ID        string
	Type      string
	Condition lua.LValue
	Action    lua.LValue
	Active    bool
}

type Mission struct {
	Name        string
	Description string
	Objectives  []string
	State       map[string]interface{}
	IsActive    bool
	IsComplete  bool
	StartTime   time.Time
}

func NewLuaEngine(u *universe.Universe) *LuaEngine {
	L := lua.NewState()

	engine := &LuaEngine{
		state:    L,
		universe: u,
		triggers: make(map[string]*Trigger),
		events:   make(map[string][]lua.LValue),
		missions: make(map[string]*Mission),
	}

	engine.setupAPI()
	return engine
}

func (le *LuaEngine) Close() {
	le.state.Close()
}

func (le *LuaEngine) setupAPI() {
	L := le.state

	L.SetGlobal("universe", luar.New(L, le.universe))
	L.SetGlobal("utils", luar.New(L, utils.Vector3{}))

	L.SetGlobal("createObject", L.NewFunction(le.luaCreateObject))
	L.SetGlobal("destroyObject", L.NewFunction(le.luaDestroyObject))
	L.SetGlobal("getObject", L.NewFunction(le.luaGetObject))
	L.SetGlobal("modifyObject", L.NewFunction(le.luaModifyObject))
	L.SetGlobal("moveObject", L.NewFunction(le.luaMoveObject))

	L.SetGlobal("createTrigger", L.NewFunction(le.luaCreateTrigger))
	L.SetGlobal("removeTrigger", L.NewFunction(le.luaRemoveTrigger))
	L.SetGlobal("checkTrigger", L.NewFunction(le.luaCheckTrigger))

	L.SetGlobal("sendMessage", L.NewFunction(le.luaSendMessage))
	L.SetGlobal("broadcastMessage", L.NewFunction(le.luaBroadcastMessage))
	L.SetGlobal("setAlertLevel", L.NewFunction(le.luaSetAlertLevel))
	L.SetGlobal("setTimeAcceleration", L.NewFunction(le.luaSetTimeAcceleration))

	L.SetGlobal("spawnShip", L.NewFunction(le.luaSpawnShip))
	L.SetGlobal("spawnPlanet", L.NewFunction(le.luaSpawnPlanet))
	L.SetGlobal("spawnStation", L.NewFunction(le.luaSpawnStation))
	L.SetGlobal("spawnAsteroid", L.NewFunction(le.luaSpawnAsteroid))
	L.SetGlobal("spawnMine", L.NewFunction(le.luaSpawnMine))

	L.SetGlobal("getPlayerShip", L.NewFunction(le.luaGetPlayerShip))
	L.SetGlobal("getDistance", L.NewFunction(le.luaGetDistance))
	L.SetGlobal("getObjectsInRange", L.NewFunction(le.luaGetObjectsInRange))

	L.SetGlobal("createExplosion", L.NewFunction(le.luaCreateExplosion))
	L.SetGlobal("createEffect", L.NewFunction(le.luaCreateEffect))

	L.SetGlobal("startMission", L.NewFunction(le.luaStartMission))
	L.SetGlobal("completeMission", L.NewFunction(le.luaCompleteMission))
	L.SetGlobal("setObjective", L.NewFunction(le.luaSetObjective))
	L.SetGlobal("completeObjective", L.NewFunction(le.luaCompleteObjective))

	L.SetGlobal("log", L.NewFunction(le.luaLog))
	L.SetGlobal("wait", L.NewFunction(le.luaWait))
	L.SetGlobal("random", L.NewFunction(le.luaRandom))

	L.SetGlobal("Vector3", L.NewFunction(le.luaVector3))
}

func (le *LuaEngine) LoadMissionFile(filename string) error {
	return le.state.DoFile(filename)
}

func (le *LuaEngine) ExecuteString(script string) error {
	return le.state.DoString(script)
}

func (le *LuaEngine) Update(deltaTime float64) {
	for _, trigger := range le.triggers {
		if trigger.Active {
			le.checkAndExecuteTrigger(trigger)
		}
	}
}

func (le *LuaEngine) checkAndExecuteTrigger(trigger *Trigger) {
	L := le.state

	if trigger.Condition != nil {
		L.Push(trigger.Condition)
		err := L.PCall(0, 1, nil)
		if err != nil {
			log.Printf("Trigger condition error: %v", err)
			return
		}

		result := L.Get(-1)
		L.Pop(1)

		if lua.LVAsBool(result) {
			if trigger.Action != nil {
				L.Push(trigger.Action)
				err := L.PCall(0, 0, nil)
				if err != nil {
					log.Printf("Trigger action error: %v", err)
				}
			}
		}
	}
}

func (le *LuaEngine) luaCreateObject(L *lua.LState) int {
	objType := L.ToString(1)
	name := L.ToString(2)
	x := L.ToNumber(3)
	y := L.ToNumber(4)
	z := L.ToNumber(5)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_%s_%d", objType, time.Now().UnixNano())

	var obj *universe.Object

	switch objType {
	case "ship":
		ship := universe.NewPlayerShip(id, name, position)
		ship.IsPlayerShip = false
		le.universe.AddShip(ship)
		obj = &ship.Object
	case "planet":
		radius := 1000.0
		if L.GetTop() > 5 {
			radius = float64(L.ToNumber(6))
		}
		obj = universe.NewPlanet(id, name, position, radius)
		le.universe.AddObject(obj)
	case "station":
		obj = universe.NewStation(id, name, position)
		le.universe.AddObject(obj)
	case "asteroid":
		obj = universe.NewAsteroid(id, position)
		le.universe.AddObject(obj)
	case "mine":
		damage := 500.0
		if L.GetTop() > 5 {
			damage = float64(L.ToNumber(6))
		}
		obj = universe.NewMine(id, position, damage)
		le.universe.AddObject(obj)
	}

	if obj != nil {
		L.Push(lua.LString(obj.ID))
		return 1
	}

	L.Push(lua.LNil)
	return 1
}

func (le *LuaEngine) luaDestroyObject(L *lua.LState) int {
	objectID := L.ToString(1)
	le.universe.RemoveObject(objectID)
	return 0
}

func (le *LuaEngine) luaGetObject(L *lua.LState) int {
	objectID := L.ToString(1)
	obj := le.universe.GetObject(objectID)

	if obj != nil {
		L.Push(luar.New(L, obj))
		return 1
	}

	L.Push(lua.LNil)
	return 1
}

func (le *LuaEngine) luaModifyObject(L *lua.LState) int {
	objectID := L.ToString(1)
	property := L.ToString(2)
	value := L.Get(3)

	obj := le.universe.GetObject(objectID)
	if obj == nil {
		return 0
	}

	switch property {
	case "position":
		if table, ok := value.(*lua.LTable); ok {
			x := table.RawGetInt(1).(lua.LNumber)
			y := table.RawGetInt(2).(lua.LNumber)
			z := table.RawGetInt(3).(lua.LNumber)
			obj.Position = utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
		}
	case "velocity":
		if table, ok := value.(*lua.LTable); ok {
			x := table.RawGetInt(1).(lua.LNumber)
			y := table.RawGetInt(2).(lua.LNumber)
			z := table.RawGetInt(3).(lua.LNumber)
			obj.Velocity = utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
		}
	case "health":
		if num, ok := value.(lua.LNumber); ok {
			obj.Health = float64(num)
		}
	case "shield":
		if num, ok := value.(lua.LNumber); ok {
			obj.Shield = float64(num)
		}
	}

	return 0
}

func (le *LuaEngine) luaMoveObject(L *lua.LState) int {
	objectID := L.ToString(1)
	x := L.ToNumber(2)
	y := L.ToNumber(3)
	z := L.ToNumber(4)

	obj := le.universe.GetObject(objectID)
	if obj != nil {
		obj.Position = utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	}

	return 0
}

func (le *LuaEngine) luaCreateTrigger(L *lua.LState) int {
	triggerID := L.ToString(1)
	triggerType := L.ToString(2)
	condition := L.Get(3)
	action := L.Get(4)

	trigger := &Trigger{
		ID:        triggerID,
		Type:      triggerType,
		Condition: condition,
		Action:    action,
		Active:    true,
	}

	le.triggers[triggerID] = trigger
	return 0
}

func (le *LuaEngine) luaRemoveTrigger(L *lua.LState) int {
	triggerID := L.ToString(1)
	delete(le.triggers, triggerID)
	return 0
}

func (le *LuaEngine) luaCheckTrigger(L *lua.LState) int {
	triggerID := L.ToString(1)

	if trigger, exists := le.triggers[triggerID]; exists {
		L.Push(lua.LBool(trigger.Active))
		return 1
	}

	L.Push(lua.LBool(false))
	return 1
}

func (le *LuaEngine) luaSendMessage(L *lua.LState) int {
	targetID := L.ToString(1)
	message := L.ToString(2)
	priority := int(L.ToNumber(3))

	playerShip := le.universe.GetPlayerShip()
	if playerShip != nil {
		msg := map[string]interface{}{
			"from":      "mission_control",
			"to":        targetID,
			"message":   message,
			"priority":  priority,
			"timestamp": time.Now(),
		}

		if messages, exists := playerShip.Properties["incoming_messages"]; exists {
			if msgList, ok := messages.([]interface{}); ok {
				msgList = append(msgList, msg)
				playerShip.Properties["incoming_messages"] = msgList
			}
		} else {
			playerShip.Properties["incoming_messages"] = []interface{}{msg}
		}
	}

	return 0
}

func (le *LuaEngine) luaBroadcastMessage(L *lua.LState) int {
	message := L.ToString(1)
	priority := int(L.ToNumber(2))

	playerShip := le.universe.GetPlayerShip()
	if playerShip != nil {
		broadcast := map[string]interface{}{
			"type":      "broadcast",
			"message":   message,
			"priority":  priority,
			"timestamp": time.Now(),
		}
		playerShip.Properties["mission_broadcast"] = broadcast
	}

	return 0
}

func (le *LuaEngine) luaSetAlertLevel(L *lua.LState) int {
	level := int(L.ToNumber(1))
	le.universe.SetAlertLevel(level)
	return 0
}

func (le *LuaEngine) luaSetTimeAcceleration(L *lua.LState) int {
	factor := float64(L.ToNumber(1))
	le.universe.SetTimeAcceleration(factor)
	return 0
}

func (le *LuaEngine) luaSpawnShip(L *lua.LState) int {
	name := L.ToString(1)
	x := L.ToNumber(2)
	y := L.ToNumber(3)
	z := L.ToNumber(4)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_ship_%d", time.Now().UnixNano())

	ship := universe.NewPlayerShip(id, name, position)
	ship.IsPlayerShip = false
	le.universe.AddShip(ship)

	L.Push(lua.LString(ship.ID))
	return 1
}

func (le *LuaEngine) luaSpawnPlanet(L *lua.LState) int {
	name := L.ToString(1)
	x := L.ToNumber(2)
	y := L.ToNumber(3)
	z := L.ToNumber(4)
	radius := L.ToNumber(5)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_planet_%d", time.Now().UnixNano())

	planet := universe.NewPlanet(id, name, position, float64(radius))
	le.universe.AddObject(planet)

	L.Push(lua.LString(planet.ID))
	return 1
}

func (le *LuaEngine) luaSpawnStation(L *lua.LState) int {
	name := L.ToString(1)
	x := L.ToNumber(2)
	y := L.ToNumber(3)
	z := L.ToNumber(4)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_station_%d", time.Now().UnixNano())

	station := universe.NewStation(id, name, position)
	le.universe.AddObject(station)

	L.Push(lua.LString(station.ID))
	return 1
}

func (le *LuaEngine) luaSpawnAsteroid(L *lua.LState) int {
	x := L.ToNumber(1)
	y := L.ToNumber(2)
	z := L.ToNumber(3)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_asteroid_%d", time.Now().UnixNano())

	asteroid := universe.NewAsteroid(id, position)
	le.universe.AddObject(asteroid)

	L.Push(lua.LString(asteroid.ID))
	return 1
}

func (le *LuaEngine) luaSpawnMine(L *lua.LState) int {
	x := L.ToNumber(1)
	y := L.ToNumber(2)
	z := L.ToNumber(3)
	damage := L.ToNumber(4)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	id := fmt.Sprintf("lua_mine_%d", time.Now().UnixNano())

	mine := universe.NewMine(id, position, float64(damage))
	le.universe.AddObject(mine)

	L.Push(lua.LString(mine.ID))
	return 1
}

func (le *LuaEngine) luaGetPlayerShip(L *lua.LState) int {
	playerShip := le.universe.GetPlayerShip()
	if playerShip != nil {
		L.Push(luar.New(L, playerShip))
		return 1
	}

	L.Push(lua.LNil)
	return 1
}

func (le *LuaEngine) luaGetDistance(L *lua.LState) int {
	obj1ID := L.ToString(1)
	obj2ID := L.ToString(2)

	obj1 := le.universe.GetObject(obj1ID)
	obj2 := le.universe.GetObject(obj2ID)

	if obj1 != nil && obj2 != nil {
		distance := obj1.GetDistance(obj2)
		L.Push(lua.LNumber(distance))
		return 1
	}

	L.Push(lua.LNumber(-1))
	return 1
}

func (le *LuaEngine) luaGetObjectsInRange(L *lua.LState) int {
	x := L.ToNumber(1)
	y := L.ToNumber(2)
	z := L.ToNumber(3)
	radius := L.ToNumber(4)

	center := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	objects := le.universe.Physics.GetObjectsInRange(center, float64(radius))

	table := L.NewTable()
	for i, obj := range objects {
		table.RawSetInt(i+1, lua.LString(obj.ID))
	}

	L.Push(table)
	return 1
}

func (le *LuaEngine) luaCreateExplosion(L *lua.LState) int {
	x := L.ToNumber(1)
	y := L.ToNumber(2)
	z := L.ToNumber(3)
	force := L.ToNumber(4)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	le.universe.Physics.ApplyExplosion(position, float64(force), 200)

	return 0
}

func (le *LuaEngine) luaCreateEffect(L *lua.LState) int {
	effectType := L.ToString(1)
	x := L.ToNumber(2)
	y := L.ToNumber(3)
	z := L.ToNumber(4)
	duration := L.ToNumber(5)

	position := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}

	effect := &universe.VisualEffect{
		ID:         fmt.Sprintf("lua_effect_%d", time.Now().UnixNano()),
		Type:       effectType,
		Position:   position,
		Color:      [3]float64{1.0, 1.0, 1.0},
		Intensity:  1.0,
		Duration:   float64(duration),
		TimeLeft:   float64(duration),
		Properties: make(map[string]interface{}),
	}

	le.universe.Effects[effect.ID] = effect

	L.Push(lua.LString(effect.ID))
	return 1
}

func (le *LuaEngine) luaStartMission(L *lua.LState) int {
	name := L.ToString(1)
	description := L.ToString(2)

	mission := &Mission{
		Name:        name,
		Description: description,
		Objectives:  make([]string, 0),
		State:       make(map[string]interface{}),
		IsActive:    true,
		IsComplete:  false,
		StartTime:   time.Now(),
	}

	le.missions[name] = mission

	playerShip := le.universe.GetPlayerShip()
	if playerShip != nil {
		playerShip.Properties["current_mission"] = mission
	}

	return 0
}

func (le *LuaEngine) luaCompleteMission(L *lua.LState) int {
	name := L.ToString(1)

	if mission, exists := le.missions[name]; exists {
		mission.IsComplete = true
		mission.IsActive = false
	}

	return 0
}

func (le *LuaEngine) luaSetObjective(L *lua.LState) int {
	missionName := L.ToString(1)
	objective := L.ToString(2)

	if mission, exists := le.missions[missionName]; exists {
		mission.Objectives = append(mission.Objectives, objective)
	}

	return 0
}

func (le *LuaEngine) luaCompleteObjective(L *lua.LState) int {
	missionName := L.ToString(1)
	objectiveIndex := int(L.ToNumber(2))

	if mission, exists := le.missions[missionName]; exists {
		if objectiveIndex >= 0 && objectiveIndex < len(mission.Objectives) {
			mission.Objectives[objectiveIndex] = "[COMPLETE] " + mission.Objectives[objectiveIndex]
		}
	}

	return 0
}

func (le *LuaEngine) luaLog(L *lua.LState) int {
	message := L.ToString(1)
	log.Printf("[LUA] %s", message)
	return 0
}

func (le *LuaEngine) luaWait(L *lua.LState) int {
	seconds := L.ToNumber(1)
	time.Sleep(time.Duration(float64(seconds) * float64(time.Second)))
	return 0
}

func (le *LuaEngine) luaRandom(L *lua.LState) int {
	min := L.ToNumber(1)
	max := L.ToNumber(2)

	result := float64(min) + (float64(max)-float64(min))*(float64(time.Now().UnixNano()%1000)/1000.0)
	L.Push(lua.LNumber(result))
	return 1
}

func (le *LuaEngine) luaVector3(L *lua.LState) int {
	x := L.ToNumber(1)
	y := L.ToNumber(2)
	z := L.ToNumber(3)

	vector := utils.Vector3{X: float64(x), Y: float64(y), Z: float64(z)}
	L.Push(luar.New(L, vector))
	return 1
}

func (le *LuaEngine) GetMissions() map[string]*Mission {
	return le.missions
}

func (le *LuaEngine) GetActiveMission() *Mission {
	for _, mission := range le.missions {
		if mission.IsActive {
			return mission
		}
	}
	return nil
}
