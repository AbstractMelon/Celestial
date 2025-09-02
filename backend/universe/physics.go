package universe

import (
	"celestial-backend/utils"
	"math"
)

type PhysicsEngine struct {
	Objects            []*Object
	GravitationalConst float64
	CollisionEnabled   bool
	DragCoefficient    float64
	MinimumDistance    float64
	MaxGravityDistance float64
	CollisionDamping   float64
}

type CollisionResult struct {
	Object1     *Object
	Object2     *Object
	Point       utils.Vector3
	Normal      utils.Vector3
	Penetration float64
	Impulse     float64
}

func NewPhysicsEngine() *PhysicsEngine {
	return &PhysicsEngine{
		Objects:            make([]*Object, 0),
		GravitationalConst: 6.67430e-11,
		CollisionEnabled:   true,
		DragCoefficient:    0.01,
		MinimumDistance:    1.0,
		MaxGravityDistance: 100000.0,
		CollisionDamping:   0.8,
	}
}

func (pe *PhysicsEngine) AddObject(obj *Object) {
	pe.Objects = append(pe.Objects, obj)
}

func (pe *PhysicsEngine) RemoveObject(obj *Object) {
	for i, o := range pe.Objects {
		if o.ID == obj.ID {
			pe.Objects = append(pe.Objects[:i], pe.Objects[i+1:]...)
			break
		}
	}
}

func (pe *PhysicsEngine) Update(deltaTime float64) []CollisionResult {
	collisions := make([]CollisionResult, 0)

	pe.applyGravitationalForces()
	pe.applyDrag()

	for _, obj := range pe.Objects {
		obj.Update(deltaTime)
	}

	if pe.CollisionEnabled {
		collisions = pe.detectAndResolveCollisions()
	}

	pe.updateTorpedoGuidance(deltaTime)
	pe.updateBlackHoleEffects()
	pe.updateNebulaEffects()

	return collisions
}

func (pe *PhysicsEngine) applyGravitationalForces() {
	for i := 0; i < len(pe.Objects); i++ {
		obj1 := pe.Objects[i]
		if obj1.IsStatic || obj1.Type == ObjectTypeTorpedo {
			continue
		}

		for j := i + 1; j < len(pe.Objects); j++ {
			obj2 := pe.Objects[j]
			if obj2.Type == ObjectTypeTorpedo {
				continue
			}

			distance := obj1.GetDistance(obj2)
			if distance > pe.MaxGravityDistance || distance < pe.MinimumDistance {
				continue
			}

			force := pe.calculateGravitationalForce(obj1, obj2, distance)
			direction := obj2.Position.Sub(obj1.Position).Normalize()

			if !obj1.IsStatic {
				obj1.ApplyForce(direction.Mul(force))
			}
			if !obj2.IsStatic {
				obj2.ApplyForce(direction.Mul(-force))
			}
		}
	}
}

func (pe *PhysicsEngine) calculateGravitationalForce(obj1, obj2 *Object, distance float64) float64 {
	if obj2.Type == ObjectTypeBlackHole {
		return pe.GravitationalConst * obj1.Mass * obj2.Mass * 1000 / (distance * distance)
	}
	if obj2.Type == ObjectTypePlanet {
		return pe.GravitationalConst * obj1.Mass * obj2.Mass * 100 / (distance * distance)
	}
	return pe.GravitationalConst * obj1.Mass * obj2.Mass / (distance * distance)
}

func (pe *PhysicsEngine) applyDrag() {
	for _, obj := range pe.Objects {
		if obj.IsStatic || obj.Velocity.Length() == 0 {
			continue
		}

		dragForce := obj.Velocity.Normalize().Mul(-pe.DragCoefficient * obj.Velocity.LengthSquared())
		obj.ApplyForce(dragForce)
	}
}

func (pe *PhysicsEngine) detectAndResolveCollisions() []CollisionResult {
	collisions := make([]CollisionResult, 0)

	for i := 0; i < len(pe.Objects); i++ {
		obj1 := pe.Objects[i]
		for j := i + 1; j < len(pe.Objects); j++ {
			obj2 := pe.Objects[j]

			if pe.isColliding(obj1, obj2) {
				collision := pe.resolveCollision(obj1, obj2)
				collisions = append(collisions, collision)
			}
		}
	}

	return collisions
}

func (pe *PhysicsEngine) isColliding(obj1, obj2 *Object) bool {
	distance := obj1.GetDistance(obj2)
	return distance < (obj1.Radius + obj2.Radius)
}

func (pe *PhysicsEngine) resolveCollision(obj1, obj2 *Object) CollisionResult {
	direction := obj2.Position.Sub(obj1.Position)
	distance := direction.Length()

	if distance == 0 {
		direction = utils.Vector3{X: 1, Y: 0, Z: 0}
		distance = 1
	} else {
		direction = direction.Div(distance)
	}

	penetration := (obj1.Radius + obj2.Radius) - distance
	contactPoint := obj1.Position.Add(direction.Mul(obj1.Radius))

	relativeVelocity := obj2.Velocity.Sub(obj1.Velocity)
	velocityAlongNormal := relativeVelocity.Dot(direction)

	if velocityAlongNormal > 0 {
		return CollisionResult{
			Object1:     obj1,
			Object2:     obj2,
			Point:       contactPoint,
			Normal:      direction,
			Penetration: penetration,
			Impulse:     0,
		}
	}

	restitution := pe.CollisionDamping
	impulseScalar := -(1 + restitution) * velocityAlongNormal

	totalMass := obj1.Mass + obj2.Mass
	if totalMass > 0 {
		impulseScalar /= totalMass
	}

	impulse := direction.Mul(impulseScalar)

	if !obj1.IsStatic {
		obj1.Velocity = obj1.Velocity.Sub(impulse.Mul(obj2.Mass))
		obj1.Position = obj1.Position.Sub(direction.Mul(penetration * 0.5))
	}
	if !obj2.IsStatic {
		obj2.Velocity = obj2.Velocity.Add(impulse.Mul(obj1.Mass))
		obj2.Position = obj2.Position.Add(direction.Mul(penetration * 0.5))
	}

	pe.handleCollisionDamage(obj1, obj2, impulseScalar)

	return CollisionResult{
		Object1:     obj1,
		Object2:     obj2,
		Point:       contactPoint,
		Normal:      direction,
		Penetration: penetration,
		Impulse:     impulseScalar,
	}
}

func (pe *PhysicsEngine) handleCollisionDamage(obj1, obj2 *Object, impulse float64) {
	damage := math.Abs(impulse) * 0.1

	if obj1.Type == ObjectTypeTorpedo {
		if damage, ok := obj1.Properties["damage"].(float64); ok {
			obj2.TakeDamage(damage)
		}
		obj1.Health = 0
	} else if obj2.Type == ObjectTypeTorpedo {
		if damage, ok := obj2.Properties["damage"].(float64); ok {
			obj1.TakeDamage(damage)
		}
		obj2.Health = 0
	} else {
		obj1.TakeDamage(damage)
		obj2.TakeDamage(damage)
	}

	if obj1.Type == ObjectTypeMine || obj2.Type == ObjectTypeMine {
		mine := obj1
		target := obj2
		if obj2.Type == ObjectTypeMine {
			mine = obj2
			target = obj1
		}

		if damage, ok := mine.Properties["damage"].(float64); ok {
			target.TakeDamage(damage)
		}
		mine.Health = 0
	}
}

func (pe *PhysicsEngine) updateTorpedoGuidance(deltaTime float64) {
	for _, obj := range pe.Objects {
		if obj.Type != ObjectTypeTorpedo {
			continue
		}

		guidance, hasGuidance := obj.Properties["guidance"].(bool)
		if !hasGuidance || !guidance {
			continue
		}

		targetID, hasTarget := obj.Properties["target_id"].(string)
		if !hasTarget {
			continue
		}

		target := pe.findObjectByID(targetID)
		if target == nil {
			continue
		}

		pe.guideTorpedo(obj, target, deltaTime)
	}
}

func (pe *PhysicsEngine) guideTorpedo(torpedo, target *Object, deltaTime float64) {
	toTarget := target.Position.Sub(torpedo.Position)
	distance := toTarget.Length()

	if distance < 10 {
		return
	}

	desiredDirection := toTarget.Normalize()
	currentDirection := torpedo.Velocity.Normalize()

	turnRate := 5.0 * deltaTime
	newDirection := currentDirection.Lerp(desiredDirection, turnRate).Normalize()

	speed := torpedo.Velocity.Length()
	torpedo.Velocity = newDirection.Mul(speed)

	if proximityTrigger, ok := torpedo.Properties["proximity_trigger"].(float64); ok {
		if distance <= proximityTrigger {
			if damage, ok := torpedo.Properties["damage"].(float64); ok {
				target.TakeDamage(damage)
			}
			torpedo.Health = 0
		}
	}
}

func (pe *PhysicsEngine) updateBlackHoleEffects() {
	for _, blackHole := range pe.Objects {
		if blackHole.Type != ObjectTypeBlackHole {
			continue
		}

		eventHorizon, _ := blackHole.Properties["event_horizon"].(float64)
		gravRange, _ := blackHole.Properties["gravitational_range"].(float64)

		for _, obj := range pe.Objects {
			if obj.ID == blackHole.ID || obj.IsStatic {
				continue
			}

			distance := obj.GetDistance(blackHole)

			if distance <= eventHorizon {
				obj.Health = 0
				continue
			}

			if distance <= gravRange {
				gravityStrength := 1.0 - (distance / gravRange)
				direction := blackHole.Position.Sub(obj.Position).Normalize()
				force := direction.Mul(gravityStrength * blackHole.Mass * 0.001)
				obj.ApplyForce(force)
			}
		}
	}
}

func (pe *PhysicsEngine) updateNebulaEffects() {
	for _, nebula := range pe.Objects {
		if nebula.Type != ObjectTypeNebula {
			continue
		}

		for _, obj := range pe.Objects {
			if obj.ID == nebula.ID {
				continue
			}

			distance := obj.GetDistance(nebula)
			if distance <= nebula.Radius {
				interference, _ := nebula.Properties["interference"].(float64)
				dragMultiplier := 1.0 + interference

				dragForce := obj.Velocity.Normalize().Mul(-pe.DragCoefficient * dragMultiplier * obj.Velocity.LengthSquared())
				obj.ApplyForce(dragForce)

				obj.Properties["sensor_interference"] = interference
			}
		}
	}
}

func (pe *PhysicsEngine) findObjectByID(id string) *Object {
	for _, obj := range pe.Objects {
		if obj.ID == id {
			return obj
		}
	}
	return nil
}

func (pe *PhysicsEngine) GetObjectsInRange(center utils.Vector3, radius float64) []*Object {
	objects := make([]*Object, 0)
	for _, obj := range pe.Objects {
		if center.Distance(obj.Position) <= radius {
			objects = append(objects, obj)
		}
	}
	return objects
}

func (pe *PhysicsEngine) GetObjectsInSphere(center utils.Vector3, radius float64, filter func(*Object) bool) []*Object {
	objects := make([]*Object, 0)
	for _, obj := range pe.Objects {
		if center.Distance(obj.Position) <= radius {
			if filter == nil || filter(obj) {
				objects = append(objects, obj)
			}
		}
	}
	return objects
}

func (pe *PhysicsEngine) RaycastHit(origin, direction utils.Vector3, maxDistance float64) *Object {
	normalizedDir := direction.Normalize()

	var closestObj *Object
	closestDistance := maxDistance

	for _, obj := range pe.Objects {
		toObj := obj.Position.Sub(origin)
		projLength := toObj.Dot(normalizedDir)

		if projLength < 0 || projLength > maxDistance {
			continue
		}

		closest := origin.Add(normalizedDir.Mul(projLength))
		distanceToCenter := closest.Distance(obj.Position)

		if distanceToCenter <= obj.Radius && projLength < closestDistance {
			closestObj = obj
			closestDistance = projLength
		}
	}

	return closestObj
}

func (pe *PhysicsEngine) ApplyExplosion(center utils.Vector3, force, radius float64) {
	for _, obj := range pe.Objects {
		if obj.IsStatic {
			continue
		}

		distance := center.Distance(obj.Position)
		if distance > radius {
			continue
		}

		falloff := 1.0 - (distance / radius)
		direction := obj.Position.Sub(center).Normalize()
		explosionForce := direction.Mul(force * falloff)

		obj.ApplyForce(explosionForce)
	}
}

func (pe *PhysicsEngine) GetTotalKineticEnergy() float64 {
	total := 0.0
	for _, obj := range pe.Objects {
		if !obj.IsStatic {
			velocity := obj.Velocity.Length()
			total += 0.5 * obj.Mass * velocity * velocity
		}
	}
	return total
}

func (pe *PhysicsEngine) GetObjectsByType(objType ObjectType) []*Object {
	objects := make([]*Object, 0)
	for _, obj := range pe.Objects {
		if obj.Type == objType {
			objects = append(objects, obj)
		}
	}
	return objects
}
