package server

import (
	"celestial-backend/logger"
	"celestial-backend/networking"
	"celestial-backend/stations"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

type WebSocketServer struct {
	clients        map[*WebSocketClient]bool
	stationClients map[networking.StationType][]*WebSocketClient
	broadcast      chan []byte
	register       chan *WebSocketClient
	unregister     chan *WebSocketClient
	upgrader       websocket.Upgrader
	stationManager *stations.StationManager
	mutex          sync.RWMutex
}

type WebSocketClient struct {
	conn     *websocket.Conn
	send     chan []byte
	server   *WebSocketServer
	station  networking.StationType
	clientID string
	lastPing time.Time
	mutex    sync.Mutex
	closed   bool
}

func NewWebSocketServer(stationManager *stations.StationManager) *WebSocketServer {
	return &WebSocketServer{
		clients:        make(map[*WebSocketClient]bool),
		stationClients: make(map[networking.StationType][]*WebSocketClient),
		broadcast:      make(chan []byte, 256),
		register:       make(chan *WebSocketClient),
		unregister:     make(chan *WebSocketClient),
		stationManager: stationManager,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
			ReadBufferSize:  1024,
			WriteBufferSize: 1024,
		},
	}
}

func (ws *WebSocketServer) Run() {
	for {
		select {
		case client := <-ws.register:
			ws.mutex.Lock()
			ws.clients[client] = true
			ws.mutex.Unlock()
			log.Printf("WebSocket client registered: %s", client.clientID)

		case client := <-ws.unregister:
			ws.mutex.Lock()
			if _, ok := ws.clients[client]; ok {
				delete(ws.clients, client)
				client.closeSend()

				if client.station != "" {
					stationClients := ws.stationClients[client.station]
					for i, c := range stationClients {
						if c == client {
							ws.stationClients[client.station] = append(stationClients[:i], stationClients[i+1:]...)
							break
						}
					}
				}
			}
			ws.mutex.Unlock()
			log.Printf("WebSocket client disconnected: %s", client.clientID)

		case message := <-ws.broadcast:
			ws.mutex.RLock()
			var toRemove []*WebSocketClient
			for client := range ws.clients {
				select {
				case client.send <- message:
				default:
					toRemove = append(toRemove, client)
				}
			}
			ws.mutex.RUnlock()

			if len(toRemove) > 0 {
				ws.mutex.Lock()
				for _, client := range toRemove {
					client.closeSend()
					delete(ws.clients, client)
				}
				ws.mutex.Unlock()
			}
		}
	}
}

func (ws *WebSocketServer) HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := ws.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	client := &WebSocketClient{
		conn:     conn,
		send:     make(chan []byte, 256),
		server:   ws,
		clientID: generateClientID(),
		lastPing: time.Now(),
	}

	ws.register <- client

	log.Printf("WebSocket client connected: %s", client.clientID)

	go client.writePump()
	go client.readPump()
}

func (c *WebSocketClient) readPump() {
	defer func() {
		c.server.unregister <- c
		c.conn.Close()
	}()

	c.conn.SetReadLimit(512)
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.lastPing = time.Now()
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, messageBytes, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}

		var message networking.Message
		if err := json.Unmarshal(messageBytes, &message); err != nil {
			log.Printf("Message unmarshal error: %v", err)
			continue
		}

		c.handleMessage(&message)
	}
}

func (c *WebSocketClient) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			n := len(c.send)
			for i := 0; i < n; i++ {
				w.Write([]byte{'\n'})
				w.Write(<-c.send)
			}

			if err := w.Close(); err != nil {
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func (c *WebSocketClient) handleMessage(message *networking.Message) {
	logger.Debug("Received message:", message.Type, string(message.Data))
	switch message.Type {
	case networking.MsgTypeStationConnect:
		var connectData networking.StationConnectData
		if err := message.UnmarshalData(&connectData); err != nil {
			c.sendError("Invalid station connect data", err)
			return
		}

		c.station = connectData.Station
		c.clientID = connectData.ClientID

		log.Printf("Station connected: %s (ClientID: %s)", c.station, c.clientID)

		c.server.mutex.Lock()
		c.server.stationClients[c.station] = append(c.server.stationClients[c.station], c)
		c.server.mutex.Unlock()

		// Send a state_update to confirm the connection with the client
		response, _ := networking.NewMessage(networking.MsgTypeStateUpdate, networking.StateUpdateData{
			Meta: map[string]interface{}{
				"status":    "connected",
				"station":   string(c.station),
				"client_id": c.clientID,
			},
		})
		c.sendMessage(response)

	case networking.MsgTypeInputEvent:
		var inputData networking.InputEventData
		if err := message.UnmarshalData(&inputData); err != nil {
			c.sendError("Invalid input data", err)
			return
		}

		inputData.Station = c.station
		if !c.server.stationManager.HandleInput(c.station, &inputData) {
			c.sendError("Input rejected", nil)
		}

	case networking.MsgTypeHeartbeat:
		var heartbeatData networking.HeartbeatData
		if err := message.UnmarshalData(&heartbeatData); err == nil {
			c.lastPing = time.Now()

			response, _ := networking.NewMessage(networking.MsgTypeHeartbeat, networking.HeartbeatData{
				ClientID: c.clientID,
				Ping:     heartbeatData.Ping,
			})
			c.sendMessage(response)
		}

		logger.Debug("Received heartbeat from client", "client_id", c.clientID)

	case networking.MsgTypeMissionLoad:
		if c.station != networking.StationGameMaster {
			c.sendError("Unauthorized", nil)
			return
		}

		var missionData networking.MissionLoadData
		if err := message.UnmarshalData(&missionData); err != nil {
			c.sendError("Invalid mission data", err)
			return
		}

	case networking.MsgTypeGameMasterCmd:
		if c.station != networking.StationGameMaster {
			c.sendError("Unauthorized", nil)
			return
		}

		var gmCmd networking.GameMasterCommand
		if err := message.UnmarshalData(&gmCmd); err != nil {
			c.sendError("Invalid GM command", err)
			return
		}

		inputData := &networking.InputEventData{
			Station:   c.station,
			Action:    "gamemaster_command",
			Value:     gmCmd,
			Timestamp: time.Now(),
			Context:   map[string]interface{}{"gm_command": message.Data},
		}

		c.server.stationManager.HandleInput(c.station, inputData)

	default:
		log.Printf("Unknown message type: %s", message.Type)
	}
}

func (c *WebSocketClient) sendMessage(message *networking.Message) {
	data, err := message.ToJSON()
	if err != nil {
		log.Printf("Error marshaling message: %v", err)
		return
	}

	logger.Debug("Sending message to client", "client_id", c.clientID, "message_type", message.Type)

	select {
	case c.send <- data:
	default:
		c.closeSend()
		c.server.mutex.Lock()
		delete(c.server.clients, c)
		c.server.mutex.Unlock()
	}
}

func (c *WebSocketClient) sendError(msg string, err error) {
	errorData := networking.ErrorData{
		Code:    400,
		Message: msg,
	}
	if err != nil {
		errorData.Details = err.Error()
	}

	errorMsg, _ := networking.NewMessage(networking.MsgTypeError, errorData)
	c.sendMessage(errorMsg)
}

func (c *WebSocketClient) closeSend() {
	c.mutex.Lock()
	defer c.mutex.Unlock()
	if !c.closed {
		close(c.send)
		c.closed = true
	}
}

func (ws *WebSocketServer) BroadcastToStation(station networking.StationType, message *networking.Message) {
	data, err := message.ToJSON()
	if err != nil {
		log.Printf("Error marshaling broadcast message: %v", err)
		return
	}

	ws.mutex.RLock()
	clients := ws.stationClients[station]
	ws.mutex.RUnlock()

	var toRemove []*WebSocketClient
	for _, client := range clients {
		select {
		case client.send <- data:
		default:
			toRemove = append(toRemove, client)
		}
	}

	if len(toRemove) > 0 {
		ws.mutex.Lock()
		for _, client := range toRemove {
			client.closeSend()
			delete(ws.clients, client)
		}
		ws.mutex.Unlock()
	}
}

func (ws *WebSocketServer) BroadcastToAll(message *networking.Message) {
	data, err := message.ToJSON()
	if err != nil {
		log.Printf("Error marshaling broadcast message: %v", err)
		return
	}

	ws.broadcast <- data
}

func (ws *WebSocketServer) BroadcastStateUpdate(stateUpdate *networking.StateUpdateData) {
	ws.mutex.RLock()
	defer ws.mutex.RUnlock()

	for station, clients := range ws.stationClients {
		filteredUpdate := ws.stationManager.FilterUpdate(station, &networking.UniverseState{
			Objects:          stateUpdate.Objects,
			Effects:          stateUpdate.Effects,
			PlayerShipID:     "",
			TimeAcceleration: 1.0,
			AlertLevel:       0,
			Timestamp:        time.Now(),
		})

		if len(filteredUpdate.Objects) > 0 || len(filteredUpdate.Effects) > 0 || filteredUpdate.Full != nil {
			message, _ := networking.NewMessage(networking.MsgTypeStateUpdate, filteredUpdate)
			data, _ := message.ToJSON()

			var toRemove []*WebSocketClient
			for _, client := range clients {
				select {
				case client.send <- data:
				default:
					toRemove = append(toRemove, client)
				}
			}

			if len(toRemove) > 0 {
				ws.mutex.Lock()
				for _, client := range toRemove {
					client.closeSend()
					delete(ws.clients, client)
				}
				ws.mutex.Unlock()
			}
		}
	}
}

func (ws *WebSocketServer) GetConnectedStations() map[networking.StationType]int {
	ws.mutex.RLock()
	defer ws.mutex.RUnlock()

	result := make(map[networking.StationType]int)
	for station, clients := range ws.stationClients {
		result[station] = len(clients)
	}
	return result
}

func generateClientID() string {
	return time.Now().Format("20060102150405") + "-" + randomString(6)
}

func randomString(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	b := make([]byte, length)
	for i := range b {
		b[i] = charset[time.Now().UnixNano()%int64(len(charset))]
	}
	return string(b)
}
