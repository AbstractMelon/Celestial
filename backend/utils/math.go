package utils

import (
	"math"
)

type Vector3 struct {
	X, Y, Z float64
}

func NewVector3(x, y, z float64) Vector3 {
	return Vector3{X: x, Y: y, Z: z}
}

func (v Vector3) Add(other Vector3) Vector3 {
	return Vector3{v.X + other.X, v.Y + other.Y, v.Z + other.Z}
}

func (v Vector3) Sub(other Vector3) Vector3 {
	return Vector3{v.X - other.X, v.Y - other.Y, v.Z - other.Z}
}

func (v Vector3) Mul(scalar float64) Vector3 {
	return Vector3{v.X * scalar, v.Y * scalar, v.Z * scalar}
}

func (v Vector3) Div(scalar float64) Vector3 {
	return Vector3{v.X / scalar, v.Y / scalar, v.Z / scalar}
}

func (v Vector3) Dot(other Vector3) float64 {
	return v.X*other.X + v.Y*other.Y + v.Z*other.Z
}

func (v Vector3) Cross(other Vector3) Vector3 {
	return Vector3{
		v.Y*other.Z - v.Z*other.Y,
		v.Z*other.X - v.X*other.Z,
		v.X*other.Y - v.Y*other.X,
	}
}

func (v Vector3) Length() float64 {
	return math.Sqrt(v.X*v.X + v.Y*v.Y + v.Z*v.Z)
}

func (v Vector3) LengthSquared() float64 {
	return v.X*v.X + v.Y*v.Y + v.Z*v.Z
}

func (v Vector3) Normalize() Vector3 {
	length := v.Length()
	if length == 0 {
		return Vector3{}
	}
	return v.Div(length)
}

func (v Vector3) Distance(other Vector3) float64 {
	return v.Sub(other).Length()
}

func (v Vector3) DistanceSquared(other Vector3) float64 {
	return v.Sub(other).LengthSquared()
}

func (v Vector3) Lerp(other Vector3, t float64) Vector3 {
	return v.Add(other.Sub(v).Mul(t))
}

func Clamp(value, min, max float64) float64 {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}

func Lerp(a, b, t float64) float64 {
	return a + (b-a)*t
}

func DegreesToRadians(degrees float64) float64 {
	return degrees * math.Pi / 180.0
}

func RadiansToDegrees(radians float64) float64 {
	return radians * 180.0 / math.Pi
}

func AngleBetween(v1, v2 Vector3) float64 {
	dot := v1.Normalize().Dot(v2.Normalize())
	return math.Acos(Clamp(dot, -1.0, 1.0))
}

type Quaternion struct {
	X, Y, Z, W float64
}

func NewQuaternion(x, y, z, w float64) Quaternion {
	return Quaternion{X: x, Y: y, Z: z, W: w}
}

func QuaternionFromAxisAngle(axis Vector3, angle float64) Quaternion {
	halfAngle := angle * 0.5
	sin := math.Sin(halfAngle)
	cos := math.Cos(halfAngle)
	normalizedAxis := axis.Normalize()

	return Quaternion{
		X: normalizedAxis.X * sin,
		Y: normalizedAxis.Y * sin,
		Z: normalizedAxis.Z * sin,
		W: cos,
	}
}

func (q Quaternion) Multiply(other Quaternion) Quaternion {
	return Quaternion{
		X: q.W*other.X + q.X*other.W + q.Y*other.Z - q.Z*other.Y,
		Y: q.W*other.Y - q.X*other.Z + q.Y*other.W + q.Z*other.X,
		Z: q.W*other.Z + q.X*other.Y - q.Y*other.X + q.Z*other.W,
		W: q.W*other.W - q.X*other.X - q.Y*other.Y - q.Z*other.Z,
	}
}

func (q Quaternion) Normalize() Quaternion {
	length := math.Sqrt(q.X*q.X + q.Y*q.Y + q.Z*q.Z + q.W*q.W)
	if length == 0 {
		return Quaternion{W: 1}
	}
	return Quaternion{q.X / length, q.Y / length, q.Z / length, q.W / length}
}

func (q Quaternion) RotateVector(v Vector3) Vector3 {
	qv := Vector3{q.X, q.Y, q.Z}
	t := qv.Cross(v).Mul(2.0)
	return v.Add(t.Mul(q.W)).Add(qv.Cross(t))
}

type Transform struct {
	Position Vector3
	Rotation Quaternion
	Scale    Vector3
}

func NewTransform() Transform {
	return Transform{
		Position: Vector3{},
		Rotation: Quaternion{W: 1},
		Scale:    Vector3{1, 1, 1},
	}
}

func (t Transform) TransformPoint(point Vector3) Vector3 {
	scaled := Vector3{point.X * t.Scale.X, point.Y * t.Scale.Y, point.Z * t.Scale.Z}
	rotated := t.Rotation.RotateVector(scaled)
	return rotated.Add(t.Position)
}

func (t Transform) TransformDirection(direction Vector3) Vector3 {
	return t.Rotation.RotateVector(direction)
}
