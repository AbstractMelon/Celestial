package server

import (
	"bufio"
	"celestial-backend/networking"
	"celestial-backend/panels"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"sync"
	"time"
)

type TCPServer struct {
	listener     net.Listener
	clients      map[string]*TCPClient
	panelManager *panels.PanelManager
	mutex        sync.RWMutex
	running      bool
}

type TCPClient struct {
	conn         net.Conn
	panelID      string
	lastSeen     time.Time
	server       *TCPServer
	outputQueue  chan []byte
	isConfigured bool
}

func NewTCPServer(panelManager *panels.PanelManager) *TCPServer {
	return &TCPServer{
		clients:      make(map[string]*TCPClient),
		panelManager: panelManager,
		running:      false,
	}
}

func (ts *TCPServer) Start(port int) error {
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", port))
	if err != nil {
		return fmt.Errorf("failed to start TCP server: %v", err)
	}

	ts.listener = listener
	ts.running = true

	log.Printf("TCP server listening on port %d", port)

	go ts.acceptConnections()
	go ts.heartbeatChecker()

	return nil
}

func (ts *TCPServer) Stop() error {
	ts.running = false

	if ts.listener != nil {
		ts.listener.Close()
	}

	ts.mutex.Lock()
	for _, client := range ts.clients {
		client.conn.Close()
	}
	ts.clients = make(map[string]*TCPClient)
	ts.mutex.Unlock()

	log.Println("TCP server stopped")
	return nil
}

func (ts *TCPServer) acceptConnections() {
	for ts.running {
		conn, err := ts.listener.Accept()
		if err != nil {
			if ts.running {
				log.Printf("TCP accept error: %v", err)
			}
			continue
		}

		client := &TCPClient{
			conn:         conn,
			lastSeen:     time.Now(),
			server:       ts,
			outputQueue:  make(chan []byte, 100),
			isConfigured: false,
		}

		go client.handleConnection()
	}
}

func (ts *TCPServer) heartbeatChecker() {
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for ts.running {
		select {
		case <-ticker.C:
			ts.checkClientHeartbeats()
		}
	}
}

func (ts *TCPServer) checkClientHeartbeats() {
	ts.mutex.Lock()
	defer ts.mutex.Unlock()

	timeout := 60 * time.Second
	now := time.Now()

	for panelID, client := range ts.clients {
		if now.Sub(client.lastSeen) > timeout {
			log.Printf("Panel %s timed out, disconnecting", panelID)
			client.conn.Close()
			delete(ts.clients, panelID)
			ts.panelManager.SetPanelOffline(panelID)
		}
	}
}

func (c *TCPClient) handleConnection() {
	defer func() {
		c.conn.Close()
		c.server.mutex.Lock()
		if c.panelID != "" {
			delete(c.server.clients, c.panelID)
			c.server.panelManager.SetPanelOffline(c.panelID)
		}
		c.server.mutex.Unlock()
		log.Printf("TCP client disconnected: %s", c.panelID)
	}()

	go c.outputHandler()

	scanner := bufio.NewScanner(c.conn)
	for scanner.Scan() {
		line := scanner.Text()
		if len(line) == 0 {
			continue
		}

		var message networking.Message
		if err := json.Unmarshal([]byte(line), &message); err != nil {
			log.Printf("TCP message parse error from %s: %v", c.panelID, err)
			continue
		}

		c.lastSeen = time.Now()
		c.handleMessage(&message)
	}

	if err := scanner.Err(); err != nil {
		log.Printf("TCP read error from %s: %v", c.panelID, err)
	}
}

func (c *TCPClient) outputHandler() {
	for {
		select {
		case data, ok := <-c.outputQueue:
			if !ok {
				return
			}

			c.conn.SetWriteDeadline(time.Now().Add(5 * time.Second))
			_, err := c.conn.Write(append(data, '\n'))
			if err != nil {
				log.Printf("TCP write error to %s: %v", c.panelID, err)
				return
			}
		}
	}
}

func (c *TCPClient) handleMessage(message *networking.Message) {
	switch message.Type {
	case networking.MsgTypePanelHeartbeat:
		c.handleHeartbeat(message)

	case networking.MsgTypePanelStatus:
		c.handleStatus(message)

	case networking.MsgTypePanelInput:
		c.handleInput(message)

	default:
		log.Printf("Unknown TCP message type from %s: %s", c.panelID, message.Type)
	}
}

func (c *TCPClient) handleHeartbeat(message *networking.Message) {
	var heartbeat networking.HeartbeatData
	if err := message.UnmarshalData(&heartbeat); err != nil {
		log.Printf("Invalid heartbeat from %s: %v", c.panelID, err)
		return
	}

	if c.panelID == "" {
		c.panelID = heartbeat.ClientID
		c.server.mutex.Lock()
		c.server.clients[c.panelID] = c
		c.server.mutex.Unlock()

		log.Printf("Panel connected: %s", c.panelID)

		config := c.server.panelManager.GetPanelConfiguration(c.panelID)
		if config != nil {
			c.sendConfiguration(config)
			c.isConfigured = true
		} else {
			log.Printf("No configuration found for panel %s", c.panelID)
		}
	}

	response := networking.HeartbeatData{
		ClientID: c.panelID,
		Ping:     heartbeat.Ping,
	}

	responseMsg, _ := networking.NewMessage(networking.MsgTypePanelHeartbeat, response)
	c.sendMessage(responseMsg)

	c.server.panelManager.SetPanelOnline(c.panelID)
}

func (c *TCPClient) handleStatus(message *networking.Message) {
	var status networking.PanelStatusData
	if err := message.UnmarshalData(&status); err != nil {
		log.Printf("Invalid status from %s: %v", c.panelID, err)
		return
	}

	if c.panelID == "" {
		c.panelID = status.PanelID
		c.server.mutex.Lock()
		c.server.clients[c.panelID] = c
		c.server.mutex.Unlock()
	}

	c.server.panelManager.UpdatePanelStatus(c.panelID, &status)
}

func (c *TCPClient) handleInput(message *networking.Message) {
	if !c.isConfigured {
		log.Printf("Ignoring input from unconfigured panel %s", c.panelID)
		return
	}

	var input networking.PanelInputData
	if err := message.UnmarshalData(&input); err != nil {
		log.Printf("Invalid input from %s: %v", c.panelID, err)
		return
	}

	input.PanelID = c.panelID
	c.server.panelManager.ProcessInput(&input)
}

func (c *TCPClient) sendMessage(message *networking.Message) {
	data, err := message.ToJSON()
	if err != nil {
		log.Printf("Error marshaling TCP message: %v", err)
		return
	}

	select {
	case c.outputQueue <- data:
	default:
		log.Printf("Output queue full for panel %s", c.panelID)
	}
}

func (c *TCPClient) sendConfiguration(config *networking.PanelConfiguration) {
	configMsg, _ := networking.NewMessage(networking.MsgTypePanelConfig, config)
	c.sendMessage(configMsg)
	log.Printf("Sent configuration to panel %s", c.panelID)
}

func (ts *TCPServer) SendOutputToPanel(panelID string, output *networking.PanelOutputData) {
	ts.mutex.RLock()
	client := ts.clients[panelID]
	ts.mutex.RUnlock()

	if client != nil {
		outputMsg, _ := networking.NewMessage(networking.MsgTypePanelOutput, output)
		client.sendMessage(outputMsg)
	}
}

func (ts *TCPServer) BroadcastToAllPanels(message *networking.Message) {
	ts.mutex.RLock()
	defer ts.mutex.RUnlock()

	for _, client := range ts.clients {
		client.sendMessage(message)
	}
}

func (ts *TCPServer) GetConnectedPanels() map[string]bool {
	ts.mutex.RLock()
	defer ts.mutex.RUnlock()

	result := make(map[string]bool)
	for panelID, client := range ts.clients {
		result[panelID] = client.isConfigured
	}
	return result
}

func (ts *TCPServer) GetPanelCount() int {
	ts.mutex.RLock()
	defer ts.mutex.RUnlock()
	return len(ts.clients)
}

func (ts *TCPServer) SendConfigurationToPanel(panelID string, config *networking.PanelConfiguration) {
	ts.mutex.RLock()
	client := ts.clients[panelID]
	ts.mutex.RUnlock()

	if client != nil {
		client.sendConfiguration(config)
		client.isConfigured = true
	}
}

func (ts *TCPServer) DisconnectPanel(panelID string) {
	ts.mutex.Lock()
	defer ts.mutex.Unlock()

	if client, exists := ts.clients[panelID]; exists {
		client.conn.Close()
		delete(ts.clients, panelID)
		ts.panelManager.SetPanelOffline(panelID)
	}
}
