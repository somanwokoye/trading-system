package helpers

import (
    "fmt"
    "net/http"
    "net/http/httptest"
    "strings"
    "sync"
    "time"

    "github.com/gorilla/websocket"
)

// MockWebSocketServer simulates exchange WebSocket endpoints
type MockWebSocketServer struct {
    server   *httptest.Server
    upgrader websocket.Upgrader
    clients  map[*websocket.Conn]bool
    mutex    sync.Mutex
    messages chan string
}

// NewMockWebSocketServer creates a new mock WebSocket server
func NewMockWebSocketServer() *MockWebSocketServer {
    mock := &MockWebSocketServer{
        upgrader: websocket.Upgrader{
            CheckOrigin: func(r *http.Request) bool { return true },
        },
        clients:  make(map[*websocket.Conn]bool),
        messages: make(chan string, 100),
    }

    mux := http.NewServeMux()
    mux.HandleFunc("/ws", mock.handleWebSocket)
    mock.server = httptest.NewServer(mux)

    // Start message broadcaster
    go mock.broadcastMessages()

    return mock
}

// URL returns the WebSocket URL
func (m *MockWebSocketServer) URL() string {
    return "ws" + strings.TrimPrefix(m.server.URL, "http") + "/ws"
}

// SendMessage broadcasts a message to all connected clients
func (m *MockWebSocketServer) SendMessage(message string) {
    select {
    case m.messages <- message:
    default:
        // Channel full, skip message
    }
}

// SendTickerUpdate sends a mock ticker update
func (m *MockWebSocketServer) SendTickerUpdate(symbol string, price float64) {
    message := fmt.Sprintf(`{
        "stream": "%s@ticker",
        "data": {
            "s": "%s",
            "c": "%.8f",
            "v": "1000.00000000",
            "E": %d
        }
    }`, strings.ToLower(symbol), symbol, price, time.Now().UnixMilli())

    m.SendMessage(message)
}

// Close shuts down the mock server
func (m *MockWebSocketServer) Close() {
    close(m.messages)
    m.server.Close()
}

func (m *MockWebSocketServer) handleWebSocket(w http.ResponseWriter, r *http.Request) {
    conn, err := m.upgrader.Upgrade(w, r, nil)
    if err != nil {
        return
    }
    defer conn.Close()

    m.mutex.Lock()
    m.clients[conn] = true
    m.mutex.Unlock()

    defer func() {
        m.mutex.Lock()
        delete(m.clients, conn)
        m.mutex.Unlock()
    }()

    // Keep connection alive
    for {
        _, _, err := conn.ReadMessage()
        if err != nil {
            break
        }
    }
}

func (m *MockWebSocketServer) broadcastMessages() {
    for message := range m.messages {
        m.mutex.Lock()
        for conn := range m.clients {
            err := conn.WriteMessage(websocket.TextMessage, []byte(message))
            if err != nil {
                conn.Close()
                delete(m.clients, conn)
            }
        }
        m.mutex.Unlock()
    }
}