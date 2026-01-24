import Foundation
import Darwin

class HTTPServer: NSObject {
    private var jsonDataProvider: (() -> Data)?
    private let port: UInt16
    private var listeningSocket: Int32 = -1
    private var isRunning = false
    
    init(port: UInt16 = 8000) {
        self.port = port
        super.init()
    }
    
    func startServer(with jsonDataProvider: @escaping () -> Data) async throws -> URL {
        print("HTTPServer.startServer called")
        self.jsonDataProvider = jsonDataProvider
        
        print("HTTPServer: Starting background server thread")
        // Start the server on a background thread
        DispatchQueue.global(qos: .background).async { [weak self] in
            print("HTTPServer: Background thread started")
            self?.runServer()
        }
        
        print("HTTPServer: Waiting for server to start...")
        // Wait for server to be ready
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let url = URL(string: "http://localhost:\(self.port)")!
        print("HTTPServer: Returning URL: \(url)")
        return url
    }
    
    private func runServer() {
        print("HTTPServer: Starting server on port \(port)")
        
        // Create listening socket
        listeningSocket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard listeningSocket >= 0 else {
            print("HTTPServer: Failed to create socket")
            return
        }
        print("HTTPServer: Socket created: \(listeningSocket)")
        
        // Set socket options
        var reuseAddr: Int32 = 1
        Darwin.setsockopt(listeningSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))
        
        // Bind socket
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(port).bigEndian
        addr.sin_addr.s_addr = 0  // INADDR_ANY
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        
        var addrCopy = addr
        let bindResult = Darwin.bind(listeningSocket, withUnsafeBytes(of: &addrCopy) { ptr in
            ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
        }, socklen_t(MemoryLayout<sockaddr_in>.size))
        
        guard bindResult == 0 else {
            print("HTTPServer: Failed to bind socket to port \(port): \(errno)")
            Darwin.close(listeningSocket)
            return
        }
        print("HTTPServer: Socket bound to port \(port)")
        
        // Listen for connections
        guard Darwin.listen(listeningSocket, 5) == 0 else {
            print("HTTPServer: Failed to listen: \(errno)")
            Darwin.close(listeningSocket)
            return
        }
        
        print("HTTPServer: Listening on port \(port)")
        isRunning = true
        
        // Accept connections
        while isRunning {
            print("HTTPServer: Waiting for connections...")
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let clientSocket = Darwin.accept(
                listeningSocket,
                withUnsafeMutableBytes(of: &clientAddr) { ptr in
                    ptr.baseAddress!.assumingMemoryBound(to: sockaddr.self)
                },
                &clientAddrLen
            )
            
            print("HTTPServer: Accept returned: \(clientSocket)")
            
            if clientSocket >= 0 {
                print("HTTPServer: Client connected, socket: \(clientSocket)")
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.handleClient(socket: clientSocket)
                }
            } else if errno != EINTR {
                print("HTTPServer: Accept error: \(errno)")
                break
            }
        }
        
        Darwin.close(listeningSocket)
        print("HTTPServer: Stopped")
    }
    
    private func handleClient(socket: Int32) {
        defer { Darwin.close(socket) }
        
        // Read HTTP request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = Darwin.read(socket, &buffer, buffer.count)
        
        guard bytesRead > 0 else {
            print("HTTPServer: No data received from client")
            return
        }
        
        // Parse request
        guard let request = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) else {
            print("HTTPServer: Failed to decode request")
            return
        }
        
        print("HTTPServer: Received request:\n\(request.prefix(500))")
        
        let lines = request.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard let firstLine = lines.first else { 
            print("HTTPServer: No first line in request")
            return 
        }
        
        let components = firstLine.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let path = components.count > 1 ? components[1] : "/"
        
        print("HTTPServer: Request path: \(path)")
        
        // Generate response
        if path == "/specimens.json" {
            print("HTTPServer: Serving JSON")
            let (body, contentType) = getJSONResponse()
            sendHTTPResponse(socket: socket, body: body, contentType: contentType)
        } else if path == "/styles.css" {
            print("HTTPServer: Attempting to load CSS")
            if let cssContent = loadResourceFile(name: "styles", ext: "css") {
                sendHTTPResponse(socket: socket, body: cssContent, contentType: "text/css")
            } else {
                print("HTTPServer: CSS not found, sending 404")
                sendHTTPErrorResponse(socket: socket, statusCode: 404, message: "Not Found")
            }
        } else if path == "/script.js" {
            print("HTTPServer: Attempting to load JavaScript")
            if let jsContent = loadResourceFile(name: "script", ext: "js") {
                sendHTTPResponse(socket: socket, body: jsContent, contentType: "application/javascript")
            } else {
                print("HTTPServer: JavaScript not found, sending 404")
                sendHTTPErrorResponse(socket: socket, statusCode: 404, message: "Not Found")
            }
        } else {
            print("HTTPServer: Attempting to load HTML")
            if let htmlContent = loadResourceFile(name: "index", ext: "html") {
                sendHTTPResponse(socket: socket, body: htmlContent, contentType: "text/html")
            } else {
                print("HTTPServer: HTML not found, sending fallback")
                let fallback = """
                    <!DOCTYPE html>
                    <html>
                    <head><title>Photos</title></head>
                    <body>
                        <h1>Photo Viewer</h1>
                        <p>Loading...</p>
                        <script>
                            fetch('/specimens.json').then(r => r.json()).then(data => {
                                console.log('Photos:', data);
                                document.body.innerHTML = '<h1>Photos Loaded</h1><pre>' + JSON.stringify(data, null, 2) + '</pre>';
                            }).catch(e => {
                                console.error('Error:', e);
                                document.body.innerHTML = '<h1>Error</h1><p>' + e.message + '</p>';
                            });
                        </script>
                    </body>
                    </html>
                    """
                sendHTTPResponse(socket: socket, body: fallback, contentType: "text/html")
            }
        }
    }
    
    private func getJSONResponse() -> (String, String) {
        if let provider = jsonDataProvider {
            let jsonData = provider()
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("HTTPServer: Serving fresh JSON data (\(jsonData.count) bytes)")
                return (jsonString, "application/json")
            }
        }
        print("HTTPServer: No JSON data provider, returning empty array")
        return ("[]", "application/json")
    }
    
    private func sendHTTPResponse(socket: Int32, body: String, contentType: String) {
        guard let bodyData = body.data(using: .utf8) else {
            print("HTTPServer: Failed to encode body")
            return
        }
        
        // Build headers with explicit CRLF line endings and blank line separator
        var headerString = "HTTP/1.1 200 OK\r\n"
        headerString += "Content-Type: \(contentType); charset=utf-8\r\n"
        headerString += "Content-Length: \(bodyData.count)\r\n"
        headerString += "Connection: close\r\n"
        headerString += "Access-Control-Allow-Origin: *\r\n"
        headerString += "\r\n"  // Blank line separator
        
        guard let headerData = headerString.data(using: .utf8) else {
            print("HTTPServer: Failed to encode headers")
            return
        }
        
        print("HTTPServer: Sending response - headers: \(headerData.count) bytes, body: \(bodyData.count) bytes")
        
        let headerWritten = Darwin.write(socket, (headerData as NSData).bytes, headerData.count)
        print("HTTPServer: Headers written: \(headerWritten) bytes")
        
        let bodyWritten = Darwin.write(socket, (bodyData as NSData).bytes, bodyData.count)
        print("HTTPServer: Body written: \(bodyWritten) bytes")
    }
    
    private func sendHTTPErrorResponse(socket: Int32, statusCode: Int, message: String) {
        let statusMessage = statusCode == 404 ? "Not Found" : "Internal Server Error"
        let errorHTML = "<html><body><h1>\(statusCode) \(statusMessage)</h1></body></html>"
        
        guard let bodyData = errorHTML.data(using: .utf8) else {
            return
        }
        
        var headerString = "HTTP/1.1 \(statusCode) \(statusMessage)\r\n"
        headerString += "Content-Type: text/html; charset=utf-8\r\n"
        headerString += "Content-Length: \(bodyData.count)\r\n"
        headerString += "Connection: close\r\n"
        headerString += "\r\n"  // Blank line separator
        
        guard let headerData = headerString.data(using: .utf8) else {
            return
        }
        
        Darwin.write(socket, (headerData as NSData).bytes, headerData.count)
        Darwin.write(socket, (bodyData as NSData).bytes, bodyData.count)
    }
    
    private func loadResourceFile(name: String, ext: String) -> String? {
        guard let resourceURL = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("HTTPServer: Resource file not found: \(name).\(ext)")
            print("HTTPServer: Bundle main path: \(Bundle.main.bundlePath)")
            print("HTTPServer: Bundle resources path: \(Bundle.main.resourcePath ?? "nil")")
            // List available resources
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("HTTPServer: Available resources: \(contents)")
                } catch {
                    print("HTTPServer: Error reading bundle resources: \(error)")
                }
            }
            return nil
        }
        
        do {
            let content = try String(contentsOf: resourceURL, encoding: .utf8)
            print("HTTPServer: Loaded resource: \(name).\(ext) (\(content.count) bytes)")
            return content
        } catch {
            print("HTTPServer: Failed to load resource: \(error)")
            return nil
        }
    }
    
    func stop() {
        print("HTTPServer: Stopping server...")
        isRunning = false
        if listeningSocket >= 0 {
            Darwin.shutdown(listeningSocket, SHUT_RDWR)
            Darwin.close(listeningSocket)
            listeningSocket = -1
        }
    }
    
    deinit {
        stop()
    }
}

