import Foundation
import Combine
import CoreBluetooth

final class BluetoothManager: NSObject, ObservableObject {
    static let shared = BluetoothManager()

    @Published var state: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var peripherals: [DiscoveredPeripheral] = []
    @Published var lastError: String?
    @Published var connectedPeripheral: CBPeripheral? = nil
    @Published var currentFlexSensorValue: Int? = nil // Current flex sensor reading (2 digits)
    /// Horizontal / in-plane IMU (left–right drift), characteristic 2A57 first float when payload is 4 or 8 bytes.
    @Published var currentIMUValue: Float? = nil // Current IMU reading (float, zeroed)
    /// Vertical / leg lift axis: second float when firmware sends 8-byte payload; nil if only 4 bytes.
    @Published var currentIMUVertical: Float? = nil
    
    // Computed property for connected device name
    var connectedDeviceName: String? {
        connectedPeripheral?.name
    }

    struct DiscoveredPeripheral: Identifiable, Equatable {
        let id: UUID
        let name: String
        let peripheral: CBPeripheral
        let rssi: Int
    }

    private var central: CBCentralManager!
    private var known: [UUID: DiscoveredPeripheral] = [:]
    private var targetPrefix: String?
    
    // BLE Service and Characteristic UUIDs
    // Flex sensor: uint16_t over characteristic 2A56
    // IMU: float over characteristic 2A57
    private let flexSensorCharacteristicUUID = CBUUID(string: "2A56") // Flex sensor characteristic UUID
    private let imuCharacteristicUUID = CBUUID(string: "2A57") // IMU characteristic UUID
    
    private var flexSensorCharacteristic: CBCharacteristic?
    private var imuCharacteristic: CBCharacteristic?
    private var flexSensorReadTimer: Timer?
    private var imuReadTimer: Timer?
    private var rawIMUValue: Float? = nil // Raw horizontal IMU before offset
    private var rawIMUVertical: Float? = nil // Raw vertical IMU before offset (8-byte payload)
    private var imuZeroOffset: Float = 0.0 // Offset to zero horizontal IMU when lesson begins
    private var imuVerticalZeroOffset: Float = 0.0
    private var isIMUZeroed: Bool = false // Flag to track if IMU has been zeroed

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func startScan(targetNamePrefix: String? = nil) {
        targetPrefix = targetNamePrefix
        guard central.state == .poweredOn else {
            lastError = "Bluetooth not powered on"
            debugLog("❌ BluetoothManager: Cannot start scan - Bluetooth not powered on")
            return
        }

        known.removeAll()
        peripherals.removeAll()
        
        let prefix = targetNamePrefix ?? "all devices"
        debugLog("🔍 BluetoothManager: Starting scan for devices with prefix '\(prefix)'")

        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        isScanning = true
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        debugLog("🛑 BluetoothManager: Stopped scanning")
    }

    func connect(_ dp: DiscoveredPeripheral) {
        debugLog("🔵 BluetoothManager: Attempting to connect to '\(dp.name)' (UUID: \(dp.id))")
        central.connect(dp.peripheral, options: nil)
    }
    
    func disconnect() {
        guard let peripheral = connectedPeripheral else {
            debugLog("⚠️ BluetoothManager: No device connected to disconnect")
            return
        }
        debugLog("🔵 BluetoothManager: Disconnecting from '\(peripheral.name ?? "Unknown Device")'")
        central.cancelPeripheralConnection(peripheral)
        // The didDisconnectPeripheral delegate method will handle cleanup
    }
    
    func zeroIMUValue() {
        // Only zero once - if already zeroed, don't do it again
        guard !isIMUZeroed else {
            debugLog("📊 BluetoothManager: IMU already zeroed, skipping")
            return
        }
        
        // Store current raw IMU value as offset to zero it out (ONE TIME ONLY)
        if let rawValue = rawIMUValue {
            imuZeroOffset = rawValue
            isIMUZeroed = true
            currentIMUValue = rawValue - imuZeroOffset
            if let rawV = rawIMUVertical {
                imuVerticalZeroOffset = rawV
                currentIMUVertical = rawV - imuVerticalZeroOffset
            } else {
                imuVerticalZeroOffset = 0.0
                currentIMUVertical = nil
            }
            debugLog("📊 BluetoothManager: Zeroing IMU. H raw: \(rawValue), V raw: \(String(describing: rawIMUVertical)), zeroed H: \(currentIMUValue ?? 0), zeroed V: \(String(describing: currentIMUVertical))")
        } else {
            imuZeroOffset = 0.0
            imuVerticalZeroOffset = 0.0
            currentIMUValue = 0.0
            currentIMUVertical = rawIMUVertical != nil ? 0.0 : nil
            isIMUZeroed = true
            debugLog("📊 BluetoothManager: Zeroing IMU value ONCE. No horizontal raw, offset set to 0")
        }
    }
    
    func resetIMUZero() {
        // Reset zero flag (for when lesson ends or resets)
        isIMUZeroed = false
        imuZeroOffset = 0.0
        imuVerticalZeroOffset = 0.0
        rawIMUValue = nil
        rawIMUVertical = nil
        currentIMUValue = nil
        currentIMUVertical = nil
    }
}

extension BluetoothManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        let stateString: String
        switch central.state {
        case .unknown: stateString = "Unknown"
        case .resetting: stateString = "Resetting"
        case .unsupported: stateString = "Unsupported"
        case .unauthorized: stateString = "Unauthorized"
        case .poweredOff: stateString = "Powered Off"
        case .poweredOn: stateString = "Powered On"
        @unknown default: stateString = "Unknown"
        }
        debugLog("📡 BluetoothManager: State changed to \(stateString)")
        if central.state != .poweredOn {
            isScanning = false
            if connectedPeripheral != nil {
                connectedPeripheral = nil
                debugLog("📱 Bluetooth Status: NOT connected to RealRehab device (Bluetooth powered off)")
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "Unknown"

        if let prefix = targetPrefix,
           name.lowercased().hasPrefix(prefix.lowercased()) == false {
            return
        }

        let dp = DiscoveredPeripheral(
            id: peripheral.identifier,
            name: name,
            peripheral: peripheral,
            rssi: RSSI.intValue
        )

        if known[dp.id] == nil {
            known[dp.id] = dp
            peripherals = Array(known.values)
            debugLog("📡 BluetoothManager: Discovered device '\(dp.name)' (RSSI: \(dp.rssi), UUID: \(dp.id))")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        connectedPeripheral = peripheral
        let deviceName = peripheral.name ?? "Unknown Device"
        debugLog("✅ BluetoothManager: CONNECTED to '\(deviceName)' (UUID: \(peripheral.identifier))")
        debugLog("📱 Bluetooth Status: Connected to RealRehab device")
        
        // Discover services after connection
        debugLog("🔍 BluetoothManager: Discovering services...")
        peripheral.discoverServices(nil) // Discover all services to find the flex sensor service
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        connectedPeripheral = nil
        let deviceName = peripheral.name ?? "Unknown Device"
        let errorMsg = error?.localizedDescription ?? "Unknown error"
        debugLog("❌ BluetoothManager: FAILED to connect to '\(deviceName)' (UUID: \(peripheral.identifier))")
        debugLog("❌ Error: \(errorMsg)")
        debugLog("📱 Bluetooth Status: NOT connected to RealRehab device")
        lastError = error?.localizedDescription
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        if connectedPeripheral?.identifier == peripheral.identifier {
            connectedPeripheral = nil
            let deviceName = peripheral.name ?? "Unknown Device"
            debugLog("⚠️ BluetoothManager: DISCONNECTED from '\(deviceName)' (UUID: \(peripheral.identifier))")
            debugLog("📱 Bluetooth Status: NOT connected to RealRehab device")
            stopReadingFlexSensor()
        }
        if let error {
            debugLog("❌ Disconnect error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    // MARK: - Peripheral Delegate Methods for Service/Characteristic Discovery
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            debugLog("❌ BluetoothManager: Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            debugLog("⚠️ BluetoothManager: No services found")
            return
        }
        
        debugLog("✅ BluetoothManager: Discovered \(services.count) service(s)")
        
        for service in services {
            debugLog("📡 BluetoothManager: Service UUID: \(service.uuid)")
            // Discover characteristics for all services (we'll find the flex sensor one)
            debugLog("🔍 BluetoothManager: Discovering characteristics for service \(service.uuid)...")
            peripheral.discoverCharacteristics(nil, for: service) // Discover all characteristics
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            debugLog("❌ BluetoothManager: Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            debugLog("⚠️ BluetoothManager: No characteristics found for service \(service.uuid)")
            return
        }
        
        debugLog("✅ BluetoothManager: Discovered \(characteristics.count) characteristic(s) for service \(service.uuid)")
        
        // Look for both flex sensor and IMU characteristics
        for characteristic in characteristics {
            debugLog("📡 BluetoothManager: Characteristic UUID: \(characteristic.uuid)")
            debugLog("   Properties: \(characteristic.properties.rawValue)")
            
            // Check if this is the flex sensor characteristic (2A56)
            if characteristic.uuid == flexSensorCharacteristicUUID && flexSensorCharacteristic == nil {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.read) {
                    flexSensorCharacteristic = characteristic
                    
                    // Try to subscribe to notifications first (preferred for continuous data)
                    if characteristic.properties.contains(.notify) {
                        debugLog("🔔 BluetoothManager: Subscribing to notifications for flex sensor data...")
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if characteristic.properties.contains(.read) {
                        debugLog("📖 BluetoothManager: Characteristic supports read, starting periodic reads...")
                        startReadingFlexSensor(peripheral: peripheral, characteristic: characteristic)
                    }
                }
            }
            
            // Check if this is the IMU characteristic (2A57)
            if characteristic.uuid == imuCharacteristicUUID && imuCharacteristic == nil {
                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.read) {
                    imuCharacteristic = characteristic
                    
                    // Try to subscribe to notifications first (preferred for continuous data)
                    if characteristic.properties.contains(.notify) {
                        debugLog("🔔 BluetoothManager: Subscribing to notifications for IMU data...")
                        peripheral.setNotifyValue(true, for: characteristic)
                    } else if characteristic.properties.contains(.read) {
                        debugLog("📖 BluetoothManager: IMU characteristic supports read, starting periodic reads...")
                        startReadingIMU(peripheral: peripheral, characteristic: characteristic)
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            debugLog("❌ BluetoothManager: Error reading characteristic value: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else {
            debugLog("⚠️ BluetoothManager: No data received")
            return
        }
        
        // Check if this is the flex sensor characteristic
        if characteristic.uuid == flexSensorCharacteristicUUID {
            // Parse flex sensor data (expecting uint16_t)
            if let flexValue = parseFlexSensorData(data) {
                currentFlexSensorValue = flexValue
                // Reduced logging for performance - only log occasionally
                // debugLog("📊 BluetoothManager: Flex sensor value read: \(flexValue)")
            } else {
                debugLog("⚠️ BluetoothManager: Failed to parse flex sensor data. Raw data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
        }
        // Check if this is the IMU characteristic
        else if characteristic.uuid == imuCharacteristicUUID {
            if let payload = parseIMUPayload(data) {
                rawIMUValue = payload.horizontal
                rawIMUVertical = payload.vertical
                if isIMUZeroed {
                    currentIMUValue = payload.horizontal - imuZeroOffset
                    if let v = payload.vertical {
                        currentIMUVertical = v - imuVerticalZeroOffset
                    } else {
                        currentIMUVertical = nil
                    }
                } else {
                    currentIMUValue = payload.horizontal
                    currentIMUVertical = payload.vertical
                }
            } else {
                debugLog("⚠️ BluetoothManager: Failed to parse IMU data. Raw data: \(data.map { String(format: "%02x", $0) }.joined(separator: " "))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            debugLog("❌ BluetoothManager: Error updating notification state: \(error.localizedDescription)")
            return
        }
        
        if characteristic.isNotifying {
            if characteristic.uuid == flexSensorCharacteristicUUID {
                debugLog("✅ BluetoothManager: Successfully subscribed to notifications for flex sensor")
            } else if characteristic.uuid == imuCharacteristicUUID {
                debugLog("✅ BluetoothManager: Successfully subscribed to notifications for IMU")
            }
        } else {
            debugLog("⚠️ BluetoothManager: Notifications disabled for characteristic")
        }
    }
    
    // MARK: - Flex Sensor Data Reading
    
    private func parseFlexSensorData(_ data: Data) -> Int? {
        // Flex sensor sends uint16_t (2 bytes, little-endian)
        // Prioritize 2-byte parsing since that's the expected format
        if data.count >= 2 {
            // Parse as little-endian uint16_t
            let value = Int(data[0]) | (Int(data[1]) << 8)
            return value
        }
        
        // Fallback: Try parsing as single byte
        if data.count == 1 {
            return Int(data[0])
        }
        
        // Fallback: Try parsing as UTF-8 string (for debugging)
        if let string = String(data: data, encoding: .utf8) {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if let value = Int(trimmed) {
                return value
            }
        }
        
        return nil
    }
    
    private func startReadingFlexSensor(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        flexSensorReadTimer?.invalidate()
        flexSensorReadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, 
                  let peripheral = self.connectedPeripheral,
                  peripheral.state == .connected else {
                self?.flexSensorReadTimer?.invalidate()
                return
            }
            peripheral.readValue(for: characteristic)
        }
    }
    
    private func stopReadingFlexSensor() {
        flexSensorReadTimer?.invalidate()
        flexSensorReadTimer = nil
        imuReadTimer?.invalidate()
        imuReadTimer = nil
        flexSensorCharacteristic = nil
        currentFlexSensorValue = nil
        imuCharacteristic = nil
        resetIMUZero()
    }
    
    // MARK: - IMU Data Reading
    
    /// First float: horizontal (left/right); optional second float (8-byte payload): vertical (leg lift).
    private func parseIMUPayload(_ data: Data) -> (horizontal: Float, vertical: Float?)? {
        guard data.count >= 4 else {
            debugLog("⚠️ BluetoothManager: IMU data too short: \(data.count) bytes")
            return nil
        }
        guard let horizontal = parseFloatLE(Data(data.prefix(4))) else { return nil }
        if data.count >= 8 {
            let v = parseFloatLE(Data(data.subdata(in: 4..<8)))
            return (horizontal, v)
        }
        return (horizontal, nil)
    }

    private func parseFloatLE(_ data: Data) -> Float? {
        guard data.count >= 4 else { return nil }
        var floatValue: Float = 0.0
        let littleEndianData = Data(data.prefix(4))
        _ = withUnsafeMutableBytes(of: &floatValue) { buffer in
            littleEndianData.copyBytes(to: buffer)
        }
        if floatValue.isNaN || floatValue.isInfinite {
            let bigEndianData = Data(littleEndianData.reversed())
            _ = withUnsafeMutableBytes(of: &floatValue) { buffer in
                bigEndianData.copyBytes(to: buffer)
            }
        }
        if floatValue.isNaN || floatValue.isInfinite {
            debugLog("⚠️ BluetoothManager: Invalid IMU float value (NaN or Infinite)")
            return nil
        }
        return floatValue
    }
    
    private func startReadingIMU(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        // Start periodic reads if notifications aren't available
        // Use separate timer so both sensors can read simultaneously
        imuReadTimer?.invalidate()
        imuReadTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, 
                  let peripheral = self.connectedPeripheral,
                  peripheral.state == .connected else {
                self?.imuReadTimer?.invalidate()
                return
            }
            peripheral.readValue(for: characteristic)
        }
    }
}
